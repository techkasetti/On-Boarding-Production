# AI-04 Interview Question Generation Runbook

## Purpose
Generate interview questions based on candidate profile and/or role context.

## Preconditions
1. Candidate or Job Posting available
2. Question object metadata deployed
3. Question display UI available

## Step-by-Step Operation
1. Run question generation from UI/action.
2. Review generated questions.
3. Edit/remove if needed.
4. Re-run generation for updated context.

## Validation Checklist
1. Interview_Question__c records created
2. Questions are relevant and role aligned
3. Delete/regenerate actions work

## Failure Handling and Recovery
1. Fallback to static question bank
2. Check InterviewQuestionGenerator logs
3. Validate prompt payload completeness

## Ownership
1. Product/Operations Owner: business correctness and sign-off.
2. Salesforce Admin: configuration, visibility, and flow health.
3. Apex/Integration Owner: runtime stability, logs, retries.
