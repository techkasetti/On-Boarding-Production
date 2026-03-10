$checks = @(
  @{ obj='Shift_Template__c'; fields=@('Template_Status__c','Shift_Type__c','Recurrence__c') },
  @{ obj='Shift_Assignment__c'; fields=@('Assignment_Status__c','Employee__c','Shift_Date__c') },
  @{ obj='Attendance__c'; fields=@('Verification_Status__c','Anomaly_Flag__c','Employee__c') },
  @{ obj='Leave_Request__c'; fields=@('Status__c','Leave_Type__c','Employee__c') },
  @{ obj='Case_Assignment__c'; fields=@('Assignment_Status__c','Employee__c') }
)
foreach ($c in $checks) {
  $raw = sf sobject describe --target-org onb --sobject $c.obj --json | ConvertFrom-Json
  $names = @{}
  foreach ($f in $raw.result.fields) { $names[$f.name] = $true }
  foreach ($field in $c.fields) {
    $exists = $names.ContainsKey($field)
    Write-Output ($c.obj + ' :: ' + $field + ' :: ' + ($(if ($exists) {'EXISTS'} else {'MISSING'})))
  }
}
