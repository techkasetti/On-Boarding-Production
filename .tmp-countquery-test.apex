try {
    Integer c = Database.countQuery('SELECT COUNT() FROM Shift_Template__c WHERE Fake_Field__c = \'x\'');
    System.debug('C=' + c);
} catch (Exception e) {
    System.debug('ERR=' + e.getMessage());
}
