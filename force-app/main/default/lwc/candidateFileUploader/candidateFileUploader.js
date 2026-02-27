import { LightningElement, track } from 'lwc';
import getPresignedUrl from '@salesforce/apex/PresignController.getPresignedUrl';
import notifyUpload from '@salesforce/apex/PresignController.notifyUpload';

const ACCEPT_TYPES = '.pdf,.doc,.docx,.jpg,.jpeg,.png,.mp3,.mp4,.wav';
let uniqueId = 0;

export default class CandidateFileUploader extends LightningElement {
  @track files = [];
  candidateId = '';

  acceptTypes = ACCEPT_TYPES;

  handleCandidateChange(e) {
    this.candidateId = e.target.value;
  }

  handleFilesSelected(e) {
    const fileList = e.target.files;
    for (let i = 0; i < fileList.length; i++) {
      const f = fileList[i];
      const id = 'f_' + (++uniqueId);
      this.files = [...this.files, {
        id,
        file: f,
        name: f.name,
        size: f.size,
        type: f.type || 'application/octet-stream',
        uploading: false,
        progress: 0,
        statusMessage: 'Queued',
        humanSize: this.humanFileSize(f.size)
      }];
    }
    // reset input
    e.target.value = '';
  }

  humanFileSize(bytes) {
    const thresh = 1024;
    if (Math.abs(bytes) < thresh) return bytes + ' B';
    const units = ['KB','MB','GB','TB'];
    let u = -1;
    do {
      bytes /= thresh;
      ++u;
    } while(Math.abs(bytes) >= thresh && u < units.length - 1);
    return bytes.toFixed(1)+' '+units[u];
  }

  removeFile(e) {
    const id = e.target.dataset.id;
    this.files = this.files.filter(f => f.id !== id);
  }

  async startAllUploads() {
    // sequential or parallel -- here we do parallel up to concurrency limit (simple)
    const concurrency = 3;
    const queue = [...this.files];
    const running = [];
    while (queue.length || running.length) {
      while (running.length < concurrency && queue.length) {
        const f = queue.shift();
        const p = this.uploadFile(f).finally(() => {
          const idx = running.indexOf(p);
          if (idx > -1) running.splice(idx,1);
        });
        running.push(p);
      }
      // wait for any to finish
      await Promise.race(running);
    }
    // refresh UI if needed
  }

  startUpload(e) {
    const id = e.target.dataset.id;
    const fileObj = this.files.find(f => f.id === id);
    if (fileObj) this.uploadFile(fileObj);
  }

  async uploadFile(fileObj) {
    // guard
    if (!this.candidateId) {
      fileObj.statusMessage = 'CandidateId required';
      this.refreshFile(fileObj);
      return;
    }

    fileObj.uploading = true;
    fileObj.progress = 0;
    fileObj.statusMessage = 'Requesting upload URL';
    this.refreshFile(fileObj);

    try {
      // 1) ask Apex for presigned URL
      const resp = await getPresignedUrl({
        fileName: fileObj.name,
        contentType: fileObj.type,
        candidateId: this.candidateId
      });
      const data = JSON.parse(resp);

      if (!data.presignedUrl || !data.s3Key) {
        throw new Error('Invalid presign response');
      }

      const presignedUrl = data.presignedUrl;
      const s3Key = data.s3Key;

      fileObj.statusMessage = 'Uploading to S3';
      this.refreshFile(fileObj);

      // 2) upload directly to S3 with progress (use XHR for progress events)
      await this.uploadToS3WithProgress(fileObj.file, presignedUrl, (percent) => {
        fileObj.progress = percent;
        fileObj.statusMessage = `Uploading: ${percent}%`;
        this.refreshFile(fileObj);
      });

      fileObj.progress = 100;
      fileObj.statusMessage = 'Upload complete. Notifying Salesforce...';
      this.refreshFile(fileObj);

      // 3) notify Apex that upload completed with s3Key
      const notifyResp = await notifyUpload({
        candidateId: this.candidateId,
        s3Key,
        fileName: fileObj.name,
        fileSize: fileObj.size
      });

      fileObj.statusMessage = 'Saved in Salesforce.';
      fileObj.uploading = false;
      this.refreshFile(fileObj);
      return notifyResp;

    } catch (err) {
      // robust error handling & some retry suggestion
      console.error('Upload error', err);
      fileObj.statusMessage = 'Error: ' + (err.message || JSON.stringify(err));
      fileObj.uploading = false;
      this.refreshFile(fileObj);
      // optionally implement retry count and requeue logic
      return Promise.reject(err);
    }
  }

  uploadToS3WithProgress(file, presignedUrl, progressCb) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('PUT', presignedUrl, true);
      xhr.setRequestHeader('Content-Type', file.type);
      xhr.upload.onprogress = (ev) => {
        if (ev.lengthComputable) {
          const percent = Math.round((ev.loaded / ev.total) * 100);
          progressCb(percent);
        }
      };
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          resolve(xhr.responseText);
        } else {
          reject(new Error('S3 upload failed with status ' + xhr.status + ': ' + xhr.responseText));
        }
      };
      xhr.onerror = () => reject(new Error('S3 upload network error'));
      xhr.onabort = () => reject(new Error('Upload aborted'));
      xhr.send(file);
    });
  }

  refreshFile(fileObj) {
    // force reactive update
    this.files = this.files.map(f => f.id === fileObj.id ? { ...fileObj } : f);
  }

  // ---------- Test helper that references the uploaded PDF path per developer instruction ----------
  // This value is provided as a testing convenience; system/tooling will transform this path into a URL for test purposes.
  TEST_FILE_URL = '/mnt/data/OnBoarding_Solution_Executive_Summary_21-08-2025.pdf';
  // You can call a test flow to fetch the file from the system path and upload it using presigned URL for full end-to-end local testing.
}