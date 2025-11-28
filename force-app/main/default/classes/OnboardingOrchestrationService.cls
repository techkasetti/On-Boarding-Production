public with sharing class OnboardingOrchestrationService {

    /**
     * @description Wrapper class to return a structured response to the LWC.
     * Contains the bot's next message and the key for the next step in the conversation.
     */
    public class ChatResponse {
        @AuraEnabled
        public String botMessage { get; set; }
        @AuraEnabled
        public String nextStepKey { get; set; }

        public ChatResponse(String botMessage, String nextStepKey) {
            this.botMessage = botMessage;
            this.nextStepKey = nextStepKey;
        }
    }

    /**
     * @description The core logic engine for the chat conversation. A state machine that
     * determines the next step based on the current step and user's response.
     * @param currentStepKey The key identifying the current point in the conversation.
     * @param userResponse The text entered by the user.
     * @param collectedData A map containing all data collected from the user so far.
     * @return A ChatResponse object with the next message and step.
     */
    public static ChatResponse getNextStep(String currentStepKey, String userResponse, Map<String, Object> collectedData) {
        // This switch statement acts as the conversation's state machine.
        // It can be expanded with more complex logic or replaced with Custom Metadata for full dynamic control.
        switch on currentStepKey {
            when 'start' {
                return new ChatResponse('Great, ' + userResponse + '! What is your last name?', 'getLastName');
            }
            when 'getLastName' {
                return new ChatResponse('Thanks! What is your email address?', 'getEmail');
            }
            when 'getEmail' {
                // Here, we don't need to return a message yet because the controller will first check for duplicates.
                // The controller will then call this service again with the result.
                return new ChatResponse('', 'checkEmail');
            }
            when 'getEmail_success' {
                // This step is called by the controller after a successful email check.
                String firstName = (String)collectedData.get('firstName');
                String lastName = (String)collectedData.get('lastName');
                String email = (String)collectedData.get('email');
                String confirmationMessage = 'Perfect. Just to confirm: ' + firstName + ' ' + lastName + ', at ' + email + '. Correct? (Type \'yes\' to submit)';
                return new ChatResponse(confirmationMessage, 'getConfirmation');
            }
            when 'getConfirmation' {
                if (userResponse.equalsIgnoreCase('yes')) {
                    return new ChatResponse('Thank you! Submitting your information now...', 'registration_complete');
                } else {
                    return new ChatResponse('My apologies. Let\'s start over. What is your first name?', 'start');
                }
            }
            when else {
                return new ChatResponse('I\'m sorry, I didn\'t understand. Could you please repeat that?', currentStepKey);
            }
        }
    }
}
