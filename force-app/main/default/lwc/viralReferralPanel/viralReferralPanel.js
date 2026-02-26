import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getReferralDashboard from "@salesforce/apex/CandidateReferralController.getReferralDashboard";
import generateReferralLink from "@salesforce/apex/CandidateReferralController.generateReferralLink";
import trackShare from "@salesforce/apex/CandidateReferralController.trackShare";

const CHANNELS = ["LinkedIn", "WhatsApp", "Email", "Facebook"];

export default class ViralReferralPanel extends LightningElement {
  @api candidateId;
  @track dashboard;
  @track error;
  @track isLoading = false;

  connectedCallback() {
    this.loadDashboard();
  }

  async loadDashboard() {
    if (!this.candidateId) {
      return;
    }

    this.isLoading = true;
    try {
      this.dashboard = await getReferralDashboard({
        candidateId: this.candidateId
      });
      this.error = undefined;
    } catch (error) {
      this.error = error.body?.message || "Unable to load referral data";
    } finally {
      this.isLoading = false;
    }
  }

  async handleGenerateLink() {
    this.isLoading = true;
    try {
      this.dashboard = await generateReferralLink({
        candidateId: this.candidateId
      });
      this.showToast(
        "Success",
        "Referral link generated successfully",
        "success"
      );
    } catch (error) {
      this.showToast(
        "Error",
        error.body?.message || "Failed to generate link",
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  async handleCopyLink() {
    if (!this.dashboard?.referralLink) {
      return;
    }
    await navigator.clipboard.writeText(this.dashboard.referralLink);
    this.showToast("Copied", "Referral link copied to clipboard", "success");
  }

  async handleSocialShare(event) {
    const channel = event.currentTarget.dataset.channel;
    try {
      this.dashboard = await trackShare({
        candidateId: this.candidateId,
        channel
      });
      const text = encodeURIComponent(
        `Join me on this platform: ${this.dashboard.referralLink}`
      );
      const urls = {
        LinkedIn: `https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(this.dashboard.referralLink)}`,
        WhatsApp: `https://wa.me/?text=${text}`,
        Email: `mailto:?subject=Join%20Me&body=${text}`,
        Facebook: `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(this.dashboard.referralLink)}`
      };
      window.open(urls[channel], "_blank");
    } catch (error) {
      this.showToast(
        "Error",
        error.body?.message || "Share tracking failed",
        "error"
      );
    }
  }

  get shareChannels() {
    return CHANNELS.map((value) => ({ value }));
  }

  get hasLink() {
    return !!this.dashboard?.referralLink;
  }

  get recentConversions() {
    return this.dashboard?.recentConversions || [];
  }

  get hasRecentConversions() {
    return this.recentConversions.length > 0;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
