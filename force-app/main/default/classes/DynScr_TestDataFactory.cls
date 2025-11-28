@isTest
public class DynScr_TestDataFactory {

    public static Map<String,Object> samplePayload() {
        return new Map<String,Object>{
            'tenantId' => '001000000000001',
            'country'  => 'US',
            'state'    => 'CA',
            'amount'   => 15000
        };
    }
}
