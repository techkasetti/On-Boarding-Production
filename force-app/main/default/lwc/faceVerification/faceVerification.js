// // faceVerification.js
// import { LightningElement, track, api } from 'lwc';
// import { ShowToastEvent }          from 'lightning/platformShowToastEvent';
// import detectFaces                 from '@salesforce/apex/FacePlusPlusService.detectFaces';
// import compareFaces                from '@salesforce/apex/FacePlusPlusService.compareFaces';
// import saveVerifiedFaceImage       from '@salesforce/apex/FacePlusPlusService.saveVerifiedFaceImage';
// import getCandidateFaceToken       from '@salesforce/apex/SignatureRequestController.getCandidateFaceToken';

// export default class FaceVerification extends LightningElement {

//     @api candidateId;

//     @track isCameraInitialized = false;
//     @track isVerifying         = false;
//     @track isVerified          = false;
//     @track isLoadingToken      = false;
//     @track confidenceDisplay   = 0;

//     // ★ Inline error messages — replaces ShowToastEvent which doesn't
//     //   work reliably in Experience Cloud guest user context
//     @track tokenErrorMessage   = '';   // shown on intro screen
//     @track verifyErrorMessage  = '';   // shown below camera during/after verify

//     cameraStream        = null;
//     videoElement        = null;
//     isVideoPlaying      = false;
//     registeredFaceToken = null;

//     // ─────────────────────────────────────────────────────
//     // GETTERS
//     // ─────────────────────────────────────────────────────
//     get isVerifyDisabled() {
//         return this.isVerifying || this.isVerified || this.isLoadingToken;
//     }
//     get hasTokenError() {
//         return !!this.tokenErrorMessage;
//     }
//     get hasVerifyError() {
//         return !!this.verifyErrorMessage;
//     }
//     get overlayFrameClass() {
//         if (this.isVerified)       return 'fv-frame fv-frame-success';
//         if (this.isVerifying)      return 'fv-frame fv-frame-scanning';
//         if (this.verifyErrorMessage) return 'fv-frame fv-frame-error';
//         return 'fv-frame fv-frame-idle';
//     }
//     get overlayLabel() {
//         if (this.isVerified)         return 'Verified ✓';
//         if (this.isVerifying)        return 'Scanning…';
//         if (this.verifyErrorMessage) return 'Not matched — try again';
//         return 'Position your face here';
//     }
//     get statusDotClass() {
//         if (this.isVerified)         return 'fv-status-dot fv-dot-success';
//         if (this.isVerifying)        return 'fv-status-dot fv-dot-scanning';
//         if (this.verifyErrorMessage) return 'fv-status-dot fv-dot-error';
//         return 'fv-status-dot fv-dot-live';
//     }
//     get statusText() {
//         if (this.isVerified)         return 'Identity confirmed';
//         if (this.isVerifying)        return 'Running face analysis…';
//         if (this.verifyErrorMessage) return 'Verification failed — try again';
//         return 'Camera live';
//     }

//     // ─────────────────────────────────────────────────────
//     // INITIALIZE CAMERA
//     // ─────────────────────────────────────────────────────
//     async initializeCamera() {
//         this.tokenErrorMessage  = '';
//         this.verifyErrorMessage = '';

//         if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
//             this.tokenErrorMessage = 'Camera access is not supported in this browser.';
//             return;
//         }

//         if (!this.candidateId) {
//             this.tokenErrorMessage = 'Candidate ID is missing. Cannot load profile photo for verification.';
//             return;
//         }

//         this.isLoadingToken = true;
//         try {
//             this.registeredFaceToken = await getCandidateFaceToken({ candidateId: this.candidateId });
//         } catch (err) {
//             this.isLoadingToken    = false;
//             this.tokenErrorMessage = err?.body?.message ||
//                 'Profile photo not found. Please upload a profile photo before verification.';
//             return;
//         }
//         this.isLoadingToken = false;

//         navigator.mediaDevices
//             .getUserMedia({ video: { facingMode: 'user' } })
//             .then(stream => {
//                 this.cameraStream        = stream;
//                 this.isCameraInitialized = true;
//             })
//             .catch(err => {
//                 let msg = 'Could not access camera.';
//                 if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
//                     msg = 'Camera permission denied. Please allow camera access and try again.';
//                 } else if (err.name === 'NotFoundError') {
//                     msg = 'No camera found on this device.';
//                 } else if (err.name === 'NotReadableError') {
//                     msg = 'Camera is in use by another application.';
//                 }
//                 this.tokenErrorMessage = msg;
//             });
//     }

//     // ─────────────────────────────────────────────────────
//     // RENDERED CALLBACK — attach camera stream
//     // ─────────────────────────────────────────────────────
//     renderedCallback() {
//         if (this.isCameraInitialized && !this.isVideoPlaying) {
//             this.videoElement = this.template.querySelector('video[data-id="video"]');
//             if (this.videoElement && this.cameraStream) {
//                 this.videoElement.srcObject = this.cameraStream;
//                 this.videoElement.play().catch(e => console.warn('[faceVerification] play():', e));
//                 this.isVideoPlaying = true;
//             }
//         }
//     }

//     // ─────────────────────────────────────────────────────
//     // CAPTURE AND VERIFY
//     // ─────────────────────────────────────────────────────
//     async captureAndVerify() {
//         this.verifyErrorMessage = ''; // clear previous error

//         if (!this.registeredFaceToken) {
//             this.verifyErrorMessage = 'No registered face token found. Please upload a profile photo.';
//             return;
//         }

//         if (!this.videoElement ||
//             this.videoElement.videoWidth  === 0 ||
//             this.videoElement.videoHeight === 0) {
//             this.verifyErrorMessage = 'Camera is still initialising. Please wait a moment and try again.';
//             return;
//         }

//         this.isVerifying = true;

//         try {
//             // Capture frame from video
//             const canvas = this.template.querySelector('canvas[data-id="canvas"]');
//             canvas.width  = this.videoElement.videoWidth;
//             canvas.height = this.videoElement.videoHeight;
//             canvas.getContext('2d').drawImage(this.videoElement, 0, 0, canvas.width, canvas.height);
//             const imageBase64 = canvas.toDataURL('image/jpeg').split(',')[1];

//             // Step 1: Detect face in live snapshot
//             const detectResult = await detectFaces({ imageBase64 });

//             if (!detectResult || detectResult.face_num === 0) {
//                 // ★ INLINE ERROR — no toast
//                 this.verifyErrorMessage =
//                     'No face detected. Make sure your face is clearly visible and well-lit, then try again.';
//                 return;
//             }

//             const liveFaceToken = detectResult.faces[0].face_token;

//             // Step 2: Compare with registered profile photo token
//             const compareResult = await compareFaces({
//                 faceToken1: this.registeredFaceToken,
//                 faceToken2: liveFaceToken
//             });

//             const confidence = compareResult?.confidence || 0;
//             this.confidenceDisplay = Math.round(confidence);

//             // ★ FACE DOES NOT MATCH — show inline error, stay on step 1
//             if (confidence < 75) {
//                 this.verifyErrorMessage =
//                     `⚠️ Profile photo does not match (confidence: ${this.confidenceDisplay}%). ` +
//                     `Please ensure good lighting, remove glasses if worn, and try again.`;
//                 // Do NOT dispatch verificationcomplete — parent stays on step 1
//                 return;
//             }

//             // ★ FACE MATCHED
//             await saveVerifiedFaceImage({ imageBase64 });

//             if (this.cameraStream) {
//                 this.cameraStream.getTracks().forEach(t => t.stop());
//             }

//             this.isVerified         = true;
//             this.verifyErrorMessage = '';

//             // Only fire event on success — parent advances to step 2
//             this.dispatchEvent(new CustomEvent('verificationcomplete', {
//                 detail: { faceVerified: true, confidence: this.confidenceDisplay }
//             }));

//         } catch (err) {
//             console.error('[faceVerification] captureAndVerify error:', err);
//             this.verifyErrorMessage =
//                 err?.body?.message || 'Face verification failed. Please try again.';
//             // Do NOT dispatch — stay on step 1
//         } finally {
//             this.isVerifying = false;
//         }
//     }

//     disconnectedCallback() {
//         if (this.cameraStream) {
//             this.cameraStream.getTracks().forEach(t => t.stop());
//         }
//     }

//     _toast(title, message, variant) {
//         this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
//     }
// }

// faceVerification.js
import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent }          from 'lightning/platformShowToastEvent';
import detectFaces                 from '@salesforce/apex/FacePlusPlusService.detectFaces';
import compareFaces                from '@salesforce/apex/FacePlusPlusService.compareFaces';
import saveVerifiedFaceImage       from '@salesforce/apex/FacePlusPlusService.saveVerifiedFaceImage';
import getCandidateFaceToken       from '@salesforce/apex/SignatureRequestController.getCandidateFaceToken';

export default class FaceVerification extends LightningElement {

    @api candidateId;

    @track isCameraInitialized = false;
    @track isVerifying         = false;
    @track isVerified          = false;
    @track isLoadingToken      = false;
    @track confidenceDisplay   = 0; 

    @track tokenErrorMessage   = '';
    @track verifyErrorMessage  = '';

    cameraStream        = null;
    videoElement        = null;
    isVideoPlaying      = false;
    registeredFaceToken = null;

    // ─────────────────────────────────────────────────────
    // GETTERS
    // ─────────────────────────────────────────────────────
    get isVerifyDisabled() {
        return this.isVerifying || this.isVerified || this.isLoadingToken;
    }
    get hasTokenError() {
        return !!this.tokenErrorMessage;
    }
    get hasVerifyError() {
        return !!this.verifyErrorMessage;
    }
    get overlayFrameClass() {
        if (this.isVerified)         return 'fv-frame fv-frame-success';
        if (this.isVerifying)        return 'fv-frame fv-frame-scanning';
        if (this.verifyErrorMessage) return 'fv-frame fv-frame-error';
        return 'fv-frame fv-frame-idle';
    }
    get overlayLabel() {
        if (this.isVerified)         return 'Verified ✓';
        if (this.isVerifying)        return 'Scanning…';
        if (this.verifyErrorMessage) return 'Not matched — try again';
        return 'Position your face here';
    }
    get statusDotClass() {
        if (this.isVerified)         return 'fv-status-dot fv-dot-success';
        if (this.isVerifying)        return 'fv-status-dot fv-dot-scanning';
        if (this.verifyErrorMessage) return 'fv-status-dot fv-dot-error';
        return 'fv-status-dot fv-dot-live';
    }
    get statusText() {
        if (this.isVerified)         return 'Identity confirmed';
        if (this.isVerifying)        return 'Running face analysis…';
        if (this.verifyErrorMessage) return 'Verification failed — try again';
        return 'Camera live';
    }

    // ─────────────────────────────────────────────────────
    // INITIALIZE CAMERA
    // ─────────────────────────────────────────────────────
    async initializeCamera() {
        this.tokenErrorMessage  = '';
        this.verifyErrorMessage = '';

        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            this.tokenErrorMessage = 'Camera access is not supported in this browser.';
            return;
        }

        if (!this.candidateId) {
            this.tokenErrorMessage = 'Candidate ID is missing. Cannot load profile photo for verification.';
            return;
        }

        this.isLoadingToken = true;
        try {
            this.registeredFaceToken = await getCandidateFaceToken({ candidateId: this.candidateId });
        } catch (err) {
            this.isLoadingToken    = false;
            this.tokenErrorMessage = err?.body?.message ||
                'Profile photo not found. Please upload a profile photo before verification.';
            return;
        }
        this.isLoadingToken = false;

        navigator.mediaDevices
            .getUserMedia({ video: { facingMode: 'user' } })
            .then(stream => {
                this.cameraStream        = stream;
                this.isCameraInitialized = true;
            })
            .catch(err => {
                let msg = 'Could not access camera.';
                if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
                    msg = 'Camera permission denied. Please allow camera access and try again.';
                } else if (err.name === 'NotFoundError') {
                    msg = 'No camera found on this device.';
                } else if (err.name === 'NotReadableError') {
                    msg = 'Camera is in use by another application.';
                }
                this.tokenErrorMessage = msg;
            });
    }

    // ─────────────────────────────────────────────────────
    // RENDERED CALLBACK — attach camera stream
    // ─────────────────────────────────────────────────────
    renderedCallback() {
        if (this.isCameraInitialized && !this.isVideoPlaying) {
            this.videoElement = this.template.querySelector('video[data-id="video"]');
            if (this.videoElement && this.cameraStream) {
                this.videoElement.srcObject = this.cameraStream;
                this.videoElement.play().catch(e => console.warn('[faceVerification] play():', e));
                this.isVideoPlaying = true;
            }
        }
    }

    // ─────────────────────────────────────────────────────
    // CAPTURE AND VERIFY
    // ─────────────────────────────────────────────────────
    async captureAndVerify() {
        this.verifyErrorMessage = '';

        if (!this.registeredFaceToken) {
            this.verifyErrorMessage = 'No registered face token found. Please upload a profile photo.';
            return;
        }

        if (!this.videoElement ||
            this.videoElement.videoWidth  === 0 ||
            this.videoElement.videoHeight === 0) {
            this.verifyErrorMessage = 'Camera is still initialising. Please wait a moment and try again.';
            return;
        }

        this.isVerifying = true;

        try {
            // Capture frame from video
            const canvas = this.template.querySelector('canvas[data-id="canvas"]');
            canvas.width  = this.videoElement.videoWidth;
            canvas.height = this.videoElement.videoHeight;
            canvas.getContext('2d').drawImage(this.videoElement, 0, 0, canvas.width, canvas.height);
            const imageBase64 = canvas.toDataURL('image/jpeg').split(',')[1];

            // Step 1: Detect face in live snapshot
            const detectResult = await detectFaces({ imageBase64 });

            if (!detectResult || detectResult.face_num === 0) {
                this.verifyErrorMessage =
                    'No face detected. Make sure your face is clearly visible and well-lit, then try again.';
                return;
            }

            const liveFaceToken = detectResult.faces[0].face_token;

            // Step 2: Compare with registered profile photo token
            const compareResult = await compareFaces({
                faceToken1: this.registeredFaceToken,
                faceToken2: liveFaceToken
            });

            const confidence = compareResult?.confidence || 0;
            this.confidenceDisplay = Math.round(confidence);

            if (confidence < 75) {
                this.verifyErrorMessage =
                    `⚠️ Profile photo does not match (confidence: ${this.confidenceDisplay}%). ` +
                    `Please ensure good lighting, remove glasses if worn, and try again.`;
                return;
            }

            // ★ Step 3: Save face image — capture the returned ContentVersion Id
            console.log('[faceVerification] captureAndVerify — saving verified face image');
const faceContentVersionId = await saveVerifiedFaceImage({
    imageBase64: imageBase64,
    requestId: this.requestId,
    signerName: this.signerName
});            console.log('[faceVerification] captureAndVerify — faceContentVersionId:', faceContentVersionId);

            if (this.cameraStream) {
                this.cameraStream.getTracks().forEach(t => t.stop());
            }

            this.isVerified         = true;
            this.verifyErrorMessage = '';

            // ★ Pass faceContentVersionId in the event so docflowsignature.js
            //   can forward it to submitSignature Apex for linking to the request
            this.dispatchEvent(new CustomEvent('verificationcomplete', {
                detail: {
                    faceVerified:          true,
                    confidence:            this.confidenceDisplay,
                    faceContentVersionId:  faceContentVersionId   // ★ NEW
                }
            }));

        } catch (err) {
            console.error('[faceVerification] captureAndVerify error:', err);
            this.verifyErrorMessage =
                err?.body?.message || 'Face verification failed. Please try again.';
        } finally {
            this.isVerifying = false;
        }
    }

    disconnectedCallback() {
        if (this.cameraStream) {
            this.cameraStream.getTracks().forEach(t => t.stop());
        }
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}