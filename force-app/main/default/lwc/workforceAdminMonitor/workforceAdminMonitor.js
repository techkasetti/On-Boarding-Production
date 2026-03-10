import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getHomeSnapshot from '@salesforce/apex/WorkforceAdminMonitorController.getHomeSnapshot';

const SHIFT_COLUMNS = [
    {
        label: 'Shift',
        fieldName: 'shiftUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'shiftName' }, target: '_blank' }
    },
    { label: 'Date', fieldName: 'shiftDate', type: 'date' },
    { label: 'Start', fieldName: 'startTimeDisplay', type: 'text' },
    { label: 'End', fieldName: 'endTimeDisplay', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Employee', fieldName: 'employeeName', type: 'text' }
];

const ATTENDANCE_COLUMNS = [
    {
        label: 'Attendance',
        fieldName: 'attendanceUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'attendanceName' }, target: '_blank' }
    },
    { label: 'Employee', fieldName: 'employeeName', type: 'text' },
    { label: 'Check In', fieldName: 'checkIn', type: 'date' },
    { label: 'Verification', fieldName: 'verificationStatus', type: 'text' },
    { label: 'Anomaly', fieldName: 'anomalyFlagText', type: 'text' },
    { label: 'Reason', fieldName: 'anomalyReason', type: 'text' }
];

const LEAVE_COLUMNS = [
    {
        label: 'Leave Request',
        fieldName: 'leaveUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'leaveName' }, target: '_blank' }
    },
    { label: 'Employee', fieldName: 'employeeName', type: 'text' },
    { label: 'Type', fieldName: 'leaveType', type: 'text' },
    { label: 'Start', fieldName: 'startDate', type: 'date' },
    { label: 'End', fieldName: 'endDate', type: 'date' },
    { label: 'Status', fieldName: 'status', type: 'text' },
    { label: 'Approver', fieldName: 'approverName', type: 'text' }
];

export default class WorkforceAdminMonitor extends LightningElement {
    @api maxRows = 10;

    wiredSnapshotResult;
    snapshot;
    errorMessage;

    shiftColumns = SHIFT_COLUMNS;
    attendanceColumns = ATTENDANCE_COLUMNS;
    leaveColumns = LEAVE_COLUMNS;
    autoRefreshHandle;

    connectedCallback() {
        this.startAutoRefresh();
    }

    disconnectedCallback() {
        this.stopAutoRefresh();
    }

    @wire(getHomeSnapshot, { maxRows: '$maxRows' })
    wiredSnapshot(value) {
        this.wiredSnapshotResult = value;
        const { data, error } = value;
        if (data) {
            this.snapshot = {
                ...data,
                scheduledShiftQueue: this.normalizeShifts(data.scheduledShiftQueue),
                attendanceExceptions: this.normalizeAttendance(data.attendanceExceptions),
                pendingLeaveQueue: this.normalizeLeaves(data.pendingLeaveQueue)
            };
            this.errorMessage = null;
        } else if (error) {
            this.snapshot = null;
            this.errorMessage = this.resolveError(error);
        }
    }

    get hasSnapshot() {
        return !!this.snapshot;
    }

    get generatedText() {
        return this.snapshot?.generatedAt ? new Date(this.snapshot.generatedAt).toLocaleString() : '';
    }

    async handleRefresh() {
        if (this.wiredSnapshotResult) {
            await refreshApex(this.wiredSnapshotResult);
        }
    }

    startAutoRefresh() {
        this.stopAutoRefresh();
        this.autoRefreshHandle = window.setInterval(() => {
            if (this.wiredSnapshotResult) {
                refreshApex(this.wiredSnapshotResult);
            }
        }, 30000);
    }

    stopAutoRefresh() {
        if (this.autoRefreshHandle) {
            window.clearInterval(this.autoRefreshHandle);
            this.autoRefreshHandle = null;
        }
    }

    normalizeShifts(rows) {
        return (rows || []).map((row) => ({
            ...row,
            shiftUrl: row.shiftId ? `/lightning/r/Shift_Assignment__c/${row.shiftId}/view` : null
        }));
    }

    normalizeAttendance(rows) {
        return (rows || []).map((row) => ({
            ...row,
            attendanceUrl: row.attendanceId
                ? `/lightning/r/Attendance__c/${row.attendanceId}/view`
                : null,
            anomalyFlagText: row.anomalyFlag ? 'Yes' : 'No'
        }));
    }

    normalizeLeaves(rows) {
        return (rows || []).map((row) => ({
            ...row,
            leaveUrl: row.leaveId ? `/lightning/r/Leave_Request__c/${row.leaveId}/view` : null
        }));
    }

    resolveError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }
        if (error.body?.message) {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }
}
