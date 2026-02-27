@IsTest
private class OnboardingOrchestrationServiceTest {
    @IsTest
    static void testConversationStateTransitions() {
        OnboardingOrchestrationService.ChatResponse startRes =
            OnboardingOrchestrationService.getNextStep('start', 'John', new Map<String, Object>());
        System.assertEquals('getLastName', startRes.nextStepKey);
        System.assert(startRes.botMessage.contains('John'));

        OnboardingOrchestrationService.ChatResponse lastNameRes =
            OnboardingOrchestrationService.getNextStep('getLastName', 'Doe', new Map<String, Object>());
        System.assertEquals('getEmail', lastNameRes.nextStepKey);

        OnboardingOrchestrationService.ChatResponse emailRes =
            OnboardingOrchestrationService.getNextStep('getEmail', 'john@example.com', new Map<String, Object>());
        System.assertEquals('checkEmail', emailRes.nextStepKey);
    }

    @IsTest
    static void testConfirmationAndFallback() {
        Map<String, Object> collectedData = new Map<String, Object>{
            'firstName' => 'Jane',
            'lastName' => 'Doe',
            'email' => 'jane@example.com'
        };

        OnboardingOrchestrationService.ChatResponse successRes =
            OnboardingOrchestrationService.getNextStep('getEmail_success', null, collectedData);
        System.assertEquals('getConfirmation', successRes.nextStepKey);
        System.assert(successRes.botMessage.contains('Jane Doe'));

        OnboardingOrchestrationService.ChatResponse yesRes =
            OnboardingOrchestrationService.getNextStep('getConfirmation', 'yes', collectedData);
        System.assertEquals('registration_complete', yesRes.nextStepKey);

        OnboardingOrchestrationService.ChatResponse noRes =
            OnboardingOrchestrationService.getNextStep('getConfirmation', 'no', collectedData);
        System.assertEquals('start', noRes.nextStepKey);

        OnboardingOrchestrationService.ChatResponse unknownRes =
            OnboardingOrchestrationService.getNextStep('unexpected', 'x', collectedData);
        System.assertEquals('unexpected', unknownRes.nextStepKey);
    }
}
