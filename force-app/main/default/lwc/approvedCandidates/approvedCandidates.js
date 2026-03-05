// approvedCandidates.js
import { LightningElement, track } from 'lwc';
import getClearedCandidates from '@salesforce/apex/DocflowDashboardController.getClearedCandidates';

const PAGE_SIZE = 10;

export default class ApprovedCandidates extends LightningElement {

    @track isLoading    = false;
    @track hasError     = false;
    @track errorMessage = '';
    @track allCandidates = [];
    @track searchTerm    = '';
    @track currentPage   = 1;
    @track sortAsc       = true;

    connectedCallback() {
        this.loadCandidates();
    }

    loadCandidates() {
        this.isLoading = true;
        this.hasError  = false;
        getClearedCandidates()
            .then(data => {
                this.allCandidates = (data || []).map((c, i) => ({
                    ...c,
                    _index:    i + 1,
                    _initials: this._initials(c.Name),
                }));
                this.isLoading = false;
            })
            .catch(err => {
                this.hasError     = true;
                this.errorMessage = err?.body?.message || 'Failed to load candidates.';
                this.isLoading    = false;
            });
    }

    handleSearch(event) {
        this.searchTerm  = event.target.value;
        this.currentPage = 1;
    }

    handleSortName() {
        this.sortAsc     = !this.sortAsc;
        this.currentPage = 1;
    }

    handlePrevPage() { if (this.currentPage > 1) this.currentPage--; }
    handleNextPage() { if (this.currentPage < this.totalPages) this.currentPage++; }

    // ── CHANGED: replaced handleView with handleGenerateDocument ──────────
    // Fires navigatesection with section='create' so docflowApp switches to
    // the Create Doc tab. Also passes candidateName so the form can pre-fill it.
    handleGenerateDocument(event) {
        console.log('event.currentTarget.dataset.name: ', event.currentTarget.dataset.name);
        console.log('event.currentTarget.dataset: ', event.currentTarget.dataset);
        const candidateName = event.currentTarget.dataset.name;

        this.dispatchEvent(new CustomEvent('navigatesection', {
            bubbles:  true,
            composed: true,
            detail: {
                section:       'create',
                candidateName: candidateName,
                candidateId:     event.currentTarget.dataset.id
            }
        }));
    }

    get searched() {
        const term = (this.searchTerm || '').toLowerCase().trim();
        if (!term) return [...this.allCandidates];
        return this.allCandidates.filter(c =>
            (c.Name || '').toLowerCase().includes(term) ||
            (c.Id   || '').toLowerCase().includes(term)
        );
    }

    get sorted() {
        return [...this.searched].sort((a, b) => {
            const nameA = (a.Name || '').toLowerCase();
            const nameB = (b.Name || '').toLowerCase();
            return this.sortAsc ? nameA.localeCompare(nameB) : nameB.localeCompare(nameA);
        });
    }

    get totalCount()  { return this.searched.length; }
    get totalPages()  { return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE)); }
    get pageStart()   { return this.totalCount === 0 ? 0 : (this.currentPage - 1) * PAGE_SIZE + 1; }
    get pageEnd()     { return Math.min(this.currentPage * PAGE_SIZE, this.totalCount); }
    get isFirstPage() { return this.currentPage <= 1; }
    get isLastPage()  { return this.currentPage >= this.totalPages; }

    get filteredCandidates() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.sorted.slice(start, start + PAGE_SIZE).map((c, i) => ({
            ...c,
            _index: start + i + 1,
        }));
    }

    get hasData() { return !this.isLoading && !this.hasError && this.filteredCandidates.length > 0; }
    get isEmpty() { return !this.isLoading && !this.hasError && this.filteredCandidates.length === 0; }

    _initials(name) {
        if (!name) return '?';
        const parts = name.trim().split(' ');
        return parts.length >= 2
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : name.slice(0, 2).toUpperCase();
    }
}