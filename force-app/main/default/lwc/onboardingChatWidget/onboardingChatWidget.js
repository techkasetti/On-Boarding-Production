import { LightningElement, api, track } from 'lwc';
import startConversationWithFlow from '@salesforce/apex/Onb_IntakeController.startConversationWithFlow';
import getConversation from '@salesforce/apex/Onb_IntakeController.getConversation';
import addMessageWithChannel from '@salesforce/apex/Onb_IntakeController.addMessageWithChannel';

// LOCAL FALLBACK STRINGS (replace with @salesforce/label imports when labels exist in the org)
const SHOW_TRANSLATED = 'Show Translated';
const SHOW_ORIGINAL  = 'Show Original';
const CHAT_PLACEHOLDER = 'Type your message...';

export default class OnboardingChatWidget extends LightningElement {
  @api candidateId;
  @api preferredLanguage;
  @track conversationId;
  @track messages = [];
  @track draft = '';
  @track showTranslated = false;

  // lowercase keys for template attribute binding
  label = {
    show_original: SHOW_ORIGINAL,
    show_translated: SHOW_TRANSLATED,
    chat_placeholder: CHAT_PLACEHOLDER
  };

  renderedCallback() {
    if (this.candidateId && !this.conversationId) {
      this.initConversation();
    }
  }

  initConversation() {
    startConversationWithFlow({ candidateId: this.candidateId, chatFlowVersion: null })
      .then(conv => {
        this.conversationId = conv.Id;
        // load conversation (translated may be filled by queueable later)
        this.loadConversation();
      })
      .catch(err => { console.error('startConversation error', err); });
  }

  loadConversation() {
    if (!this.conversationId) return;
    getConversation({ conversationId: this.conversationId })
      .then(conv => {
        // conv may contain Translated_Transcript__c and Transcript
        const raw = this.showTranslated && conv.Translated_Transcript__c ? conv.Translated_Transcript__c : conv.Transcript;
        this.parseTranscript(raw);
      })
      .catch(err => { console.error('getConversation error', err); });
  }

  parseTranscript(transcript) {
    this.messages = [];
    if (!transcript) return;
    try {
      const root = JSON.parse(transcript);
      const msgs = root.messages || [];
      this.messages = msgs.map((m, i) => ({ index: i, author: m.author, text: m.text, channel: m.channel, at: m.at }));
    } catch (e) {
      // If transcript isn't JSON (e.g., translated text is plain), create a single message entry
      this.messages = [{ index: 0, author: 'system', text: transcript, channel: 'system', at: '' }];
    }
  }

  onDraftChange(e) { this.draft = e.target.value; }

  handleSendWeb() { this.sendMessage('web'); }
  handleSendMobile() { this.sendMessage('mobile'); }

  sendMessage(channel) {
    if (!this.conversationId || !this.draft) return;
    addMessageWithChannel({ conversationId: this.conversationId, author: 'user', text: this.draft, channel: channel })
      .then(conv => {
        // After sending, clear draft then reload conversation to pick up any translation produced by queueable
        this.draft = '';
        // small delay to allow queueable to run in non-test environments
        setTimeout(() => this.loadConversation(), 800);
      })
      .catch(err => { console.error('addMessage error', err); });
  }

  get translatedToggleLabel() {
    return this.showTranslated ? this.label.show_original : this.label.show_translated;
  }

  toggleTranslated() {
    this.showTranslated = !this.showTranslated;
    this.loadConversation();
  }
}
