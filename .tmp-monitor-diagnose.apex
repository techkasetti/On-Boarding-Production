WorkforceAdminMonitorController.Snapshot snap = WorkforceAdminMonitorController.getHomeSnapshot(10);
System.debug('SNAP=' + JSON.serialize(snap));
for (AggregateResult ar : [SELECT Template_Status__c status, COUNT(Id) c FROM Shift_Template__c GROUP BY Template_Status__c]) {
    System.debug('TPL_STATUS=' + (String)ar.get('status') + ';COUNT=' + String.valueOf(ar.get('c')));
}
for (AggregateResult ar : [SELECT Assignment_Status__c status, COUNT(Id) c FROM Shift_Assignment__c GROUP BY Assignment_Status__c]) {
    System.debug('ASSIGN_STATUS=' + (String)ar.get('status') + ';COUNT=' + String.valueOf(ar.get('c')));
}
for (AggregateResult ar : [SELECT Status__c status, COUNT(Id) c FROM Leave_Request__c GROUP BY Status__c]) {
    System.debug('LEAVE_STATUS=' + (String)ar.get('status') + ';COUNT=' + String.valueOf(ar.get('c')));
}
for (AggregateResult ar : [SELECT Assignment_Status__c status, COUNT(Id) c FROM Case_Assignment__c GROUP BY Assignment_Status__c]) {
    System.debug('CASE_STATUS=' + (String)ar.get('status') + ';COUNT=' + String.valueOf(ar.get('c')));
}
for (AggregateResult ar : [SELECT Verification_Status__c ver, Anomaly_Flag__c flag, COUNT(Id) c FROM Attendance__c GROUP BY Verification_Status__c, Anomaly_Flag__c]) {
    System.debug('ATTN=' + (String)ar.get('ver') + ';FLAG=' + String.valueOf(ar.get('flag')) + ';COUNT=' + String.valueOf(ar.get('c')));
}
