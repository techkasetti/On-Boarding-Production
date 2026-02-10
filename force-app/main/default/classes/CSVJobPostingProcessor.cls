// CSVJobPostingProcessor.cls - FIXED VERSION WITH COMPREHENSIVE DEBUGGING
public class CSVJobPostingProcessor {
    
    /**
     * Parse CSV and enrich each job with AI-extracted child requirements
     * Returns list of complete job data structures ready for creation
     */
    public static List<Map<String, Object>> parseAndEnrichCSV(String csvContent) {
        List<Map<String, Object>> enrichedJobDataList = new List<Map<String, Object>>();
        
        try {
            List<String> rows = csvContent.split('\n');
            
            if (rows.isEmpty()) {
                throw new CSVParseException('CSV file is empty');
            }
            
            // Get headers from first row
            List<String> headers = parseCSVLine(rows[0]);
            System.debug('=== CSV HEADERS ===');
            System.debug('Headers: ' + headers);
            
            // Find Description column index
            Integer descriptionIndex = -1;
            for (Integer i = 0; i < headers.size(); i++) {
                if (headers[i].trim().toLowerCase() == 'description') {
                    descriptionIndex = i;
                    break;
                }
            }
            System.debug('Description column index: ' + descriptionIndex);
            
            // Process data rows
            for (Integer i = 1; i < rows.size(); i++) {
                String row = rows[i].trim();
                
                // Skip empty rows
                if (String.isBlank(row)) {
                    System.debug('Row ' + (i + 1) + ': Skipped (empty)');
                    continue;
                }
                
                List<String> values = parseCSVLine(row);
                
                if (values.isEmpty()) {
                    System.debug('Row ' + (i + 1) + ': Skipped (no values)');
                    continue;
                }
                
                System.debug('=== PROCESSING ROW ' + (i + 1) + ' ===');
                
                Map<String, Object> basicJobData = new Map<String, Object>();
                String description = '';
                
                // Map CSV columns to job fields
                for (Integer j = 0; j < headers.size() && j < values.size(); j++) {
                    String header = headers[j].trim().toLowerCase();
                    String value = values[j].trim();
                    
                    if (String.isBlank(value)) {
                        continue;
                    }
                    
                    // Capture description separately
                    if (j == descriptionIndex) {
                        description = value;
                        System.debug('Description found: ' + description.substring(0, Math.min(100, description.length())) + '...');
                    }
                    
                    String mappedField = mapCSVHeader(header);
                    
                    // Type conversion based on field type
                    if (mappedField == 'Min_Experience_Years__c' || mappedField == 'Max_Experience_Years__c') {
                        basicJobData.put(mappedField, Decimal.valueOf(value));
                    } else if (mappedField == 'Credentialing_Required__c') {
                        String lowerValue = value.toLowerCase();
                        basicJobData.put(mappedField, lowerValue == 'true' || lowerValue == 'yes' || lowerValue == '1');
                    } else if (mappedField == 'Start_Date__c' || mappedField == 'End_Date__c') {
                        basicJobData.put(mappedField, value);
                    } else {
                        basicJobData.put(mappedField, value);
                    }
                }
                
                // Validate required fields
                if (!basicJobData.containsKey('Job_Title__c') || String.isBlank((String)basicJobData.get('Job_Title__c'))) {
                    System.debug('Row ' + (i + 1) + ': Skipped - missing Job Title');
                    continue;
                }
                
                System.debug('Job Title: ' + basicJobData.get('Job_Title__c'));
                System.debug('Basic job data keys: ' + basicJobData.keySet());
                
                // USE AI TO EXTRACT CHILD REQUIREMENTS FROM DESCRIPTION
                Map<String, Object> aiEnrichedData;
                
                if (String.isNotBlank(description)) {
                    System.debug('=== CALLING AI FOR ROW ' + (i + 1) + ' ===');
                    
                    try {
                        // Build enrichment prompt
                        String enrichmentPrompt = buildEnrichmentPrompt(basicJobData, description);
                        System.debug('Enrichment prompt length: ' + enrichmentPrompt.length());
                        System.debug('Enrichment prompt (first 500 chars): ' + enrichmentPrompt.substring(0, Math.min(500, enrichmentPrompt.length())));
                        
                        // Call AI service
                        aiEnrichedData = AIJobPostingService.processNLPInput(enrichmentPrompt);
                        
                        System.debug('=== AI RESPONSE FOR ROW ' + (i + 1) + ' ===');
                        System.debug('AI Data Keys: ' + aiEnrichedData.keySet());
                        
                        // Log child record counts
                        if (aiEnrichedData.containsKey('educationRequirements')) {
                            List<Object> eduList = (List<Object>) aiEnrichedData.get('educationRequirements');
                            System.debug('Education Requirements: ' + (eduList != null ? eduList.size() : 0));
                        }
                        if (aiEnrichedData.containsKey('licenseRequirements')) {
                            List<Object> licList = (List<Object>) aiEnrichedData.get('licenseRequirements');
                            System.debug('License Requirements: ' + (licList != null ? licList.size() : 0));
                        }
                        if (aiEnrichedData.containsKey('certificationRequirements')) {
                            List<Object> certList = (List<Object>) aiEnrichedData.get('certificationRequirements');
                            System.debug('Certification Requirements: ' + (certList != null ? certList.size() : 0));
                        }
                        if (aiEnrichedData.containsKey('clinicalSkills')) {
                            List<Object> skillList = (List<Object>) aiEnrichedData.get('clinicalSkills');
                            System.debug('Clinical Skills: ' + (skillList != null ? skillList.size() : 0));
                        }
                        if (aiEnrichedData.containsKey('procedureRequirements')) {
                            List<Object> procList = (List<Object>) aiEnrichedData.get('procedureRequirements');
                            System.debug('Procedure Requirements: ' + (procList != null ? procList.size() : 0));
                        }
                        if (aiEnrichedData.containsKey('complianceRequirements')) {
                            List<Object> compList = (List<Object>) aiEnrichedData.get('complianceRequirements');
                            System.debug('Compliance Requirements: ' + (compList != null ? compList.size() : 0));
                        }
                        
                    } catch (Exception e) {
                        System.debug('Row ' + (i + 1) + ' - AI enrichment FAILED: ' + e.getMessage());
                        System.debug('Stack trace: ' + e.getStackTraceString());
                        
                        // Fallback: create job with basic data only, empty child arrays
                        aiEnrichedData = new Map<String, Object>();
                        aiEnrichedData.put('jobPosting', basicJobData);
                        aiEnrichedData.put('educationRequirements', new List<Object>());
                        aiEnrichedData.put('licenseRequirements', new List<Object>());
                        aiEnrichedData.put('certificationRequirements', new List<Object>());
                        aiEnrichedData.put('clinicalSkills', new List<Object>());
                        aiEnrichedData.put('procedureRequirements', new List<Object>());
                        aiEnrichedData.put('complianceRequirements', new List<Object>());
                        
                        System.debug('Fallback: Created job structure with empty child arrays');
                    }
                } else {
                    System.debug('Row ' + (i + 1) + ': No description found - creating with basic data only');
                    
                    // No description: create job with basic data only
                    aiEnrichedData = new Map<String, Object>();
                    aiEnrichedData.put('jobPosting', basicJobData);
                    aiEnrichedData.put('educationRequirements', new List<Object>());
                    aiEnrichedData.put('licenseRequirements', new List<Object>());
                    aiEnrichedData.put('certificationRequirements', new List<Object>());
                    aiEnrichedData.put('clinicalSkills', new List<Object>());
                    aiEnrichedData.put('procedureRequirements', new List<Object>());
                    aiEnrichedData.put('complianceRequirements', new List<Object>());
                }
                
                enrichedJobDataList.add(aiEnrichedData);
                System.debug('Row ' + (i + 1) + ': Successfully added to enrichment list');
            }
            
            System.debug('=== CSV PARSING COMPLETE ===');
            System.debug('Total jobs parsed and enriched: ' + enrichedJobDataList.size());
            
        } catch (Exception e) {
            System.debug('CRITICAL ERROR in parseAndEnrichCSV: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new CSVParseException('Error parsing CSV: ' + e.getMessage());
        }
        
        return enrichedJobDataList;
    }
    
    /**
     * Build AI enrichment prompt from basic CSV job data + description
     */
    private static String buildEnrichmentPrompt(Map<String, Object> basicJobData, String description) {
        String prompt = 'Extract comprehensive job posting details from this job description.\n\n';
        
        prompt += '=== BASIC JOB INFO ===\n';
        
        // Add all available fields to prompt
        if (basicJobData.containsKey('Job_Title__c')) {
            prompt += 'Job Title: ' + basicJobData.get('Job_Title__c') + '\n';
        }
        if (basicJobData.containsKey('Role_Type__c')) {
            prompt += 'Role Type: ' + basicJobData.get('Role_Type__c') + '\n';
        }
        if (basicJobData.containsKey('Department__c')) {
            prompt += 'Department: ' + basicJobData.get('Department__c') + '\n';
        }
        if (basicJobData.containsKey('Facility_Name__c')) {
            prompt += 'Facility: ' + basicJobData.get('Facility_Name__c') + '\n';
        }
        if (basicJobData.containsKey('City__c')) {
            prompt += 'City: ' + basicJobData.get('City__c') + '\n';
        }
        if (basicJobData.containsKey('State__c')) {
            prompt += 'State: ' + basicJobData.get('State__c') + '\n';
        }
        if (basicJobData.containsKey('Country__c')) {
            prompt += 'Country: ' + basicJobData.get('Country__c') + '\n';
        }
        if (basicJobData.containsKey('Min_Experience_Years__c') && basicJobData.containsKey('Max_Experience_Years__c')) {
            prompt += 'Experience: ' + basicJobData.get('Min_Experience_Years__c') + '-' + basicJobData.get('Max_Experience_Years__c') + ' years\n';
        }
        if (basicJobData.containsKey('Start_Date__c')) {
            prompt += 'Start Date: ' + basicJobData.get('Start_Date__c') + '\n';
        }
        if (basicJobData.containsKey('End_Date__c')) {
            prompt += 'End Date: ' + basicJobData.get('End_Date__c') + '\n';
        }
        if (basicJobData.containsKey('Privilege_Scope__c')) {
            prompt += 'Privilege Scope: ' + basicJobData.get('Privilege_Scope__c') + '\n';
        }
        
        prompt += '\n=== DETAILED DESCRIPTION WITH REQUIREMENTS ===\n';
        prompt += description + '\n\n';
        
        prompt += '=== EXTRACTION INSTRUCTIONS ===\n';
        prompt += 'From the description above, extract ALL requirements mentioned:\n';
        prompt += '- EDUCATION: Extract degree names (MBBS, MD, BSc Nursing, etc.)\n';
        prompt += '- LICENSES: Extract license/registration names and authorities\n';
        prompt += '- CERTIFICATIONS: Extract certification names (BLS, ACLS, PALS, etc.)\n';
        prompt += '- SKILLS: Extract skill names and levels (Basic/Intermediate/Advanced)\n';
        prompt += '- PROCEDURES: Extract procedure names\n';
        prompt += '- COMPLIANCE: Extract compliance requirements (HIPAA, protocols, etc.)\n';
        
        return prompt;
    }
    
    // Parse a single CSV line handling quoted fields
    private static List<String> parseCSVLine(String line) {
        List<String> result = new List<String>();
        Boolean inQuotes = false;
        String currentField = '';
        
        for (Integer i = 0; i < line.length(); i++) {
            String c = line.substring(i, i + 1);
            
            if (c == '"') {
                inQuotes = !inQuotes;
            } else if (c == ',' && !inQuotes) {
                result.add(currentField.trim());
                currentField = '';
            } else {
                currentField += c;
            }
        }
        
        result.add(currentField.trim());
        
        return result;
    }
    
    // Map CSV headers to field API names
    private static String mapCSVHeader(String header) {
        Map<String, String> headerMapping = new Map<String, String>{
            'job title' => 'Job_Title__c',
            'title' => 'Job_Title__c',
            'name' => 'Job_Title__c',
            'position' => 'Job_Title__c',
            
            'description' => 'Description__c',
            'job description' => 'Description__c',
            'details' => 'Description__c',
            
            'category' => 'Category__c',
            'type' => 'Category__c',
            
            'role type' => 'Role_Type__c',
            'role' => 'Role_Type__c',
            
            'department' => 'Department__c',
            'dept' => 'Department__c',
            
            'employment type' => 'Employment_Type__c',
            'employment' => 'Employment_Type__c',
            
            'shift type' => 'Shift_Type__c',
            'shift' => 'Shift_Type__c',
            
            'min experience' => 'Min_Experience_Years__c',
            'minimum experience' => 'Min_Experience_Years__c',
            'min exp' => 'Min_Experience_Years__c',
            
            'max experience' => 'Max_Experience_Years__c',
            'maximum experience' => 'Max_Experience_Years__c',
            'max exp' => 'Max_Experience_Years__c',
            
            'start date' => 'Start_Date__c',
            'startdate' => 'Start_Date__c',
            'opening date' => 'Start_Date__c',
            
            'end date' => 'End_Date__c',
            'enddate' => 'End_Date__c',
            'closing date' => 'End_Date__c',
            
            'facility name' => 'Facility_Name__c',
            'facility' => 'Facility_Name__c',
            'hospital' => 'Facility_Name__c',
            'clinic' => 'Facility_Name__c',
            
            'city' => 'City__c',
            'state' => 'State__c',
            'province' => 'State__c',
            'country' => 'Country__c',
            
            'credentialing required' => 'Credentialing_Required__c',
            'credentialing' => 'Credentialing_Required__c',
            
            'privilege scope' => 'Privilege_Scope__c',
            'privileges' => 'Privilege_Scope__c'
        };
        
        String mappedHeader = headerMapping.get(header);
        return mappedHeader != null ? mappedHeader : header.replaceAll(' ', '_') + '__c';
    }
    
    public class CSVParseException extends Exception {}
}