public class CSVJobPostingProcessor {
    
    public static List<Map<String, Object>> parseCSV(String csvContent) {
        List<Map<String, Object>> jobPostings = new List<Map<String, Object>>();
        
        try {
            List<String> rows = csvContent.split('\n');
            
            if (rows.isEmpty()) {
                throw new CSVParseException('CSV file is empty');
            }
            
            // Get headers from first row
            List<String> headers = parseCSVLine(rows[0]);
            System.debug('CSV Headers: ' + headers);
            
            // Process data rows
            for (Integer i = 1; i < rows.size(); i++) {
                String row = rows[i].trim();
                
                // Skip empty rows
                if (String.isBlank(row)) {
                    continue;
                }
                
                List<String> values = parseCSVLine(row);
                
                if (values.isEmpty()) {
                    continue;
                }
                
                Map<String, Object> jobData = new Map<String, Object>();
                
                // Map CSV columns to job fields
                for (Integer j = 0; j < headers.size() && j < values.size(); j++) {
                    String header = headers[j].trim().toLowerCase();
                    String value = values[j].trim();
                    
                    if (String.isBlank(value)) {
                        continue;
                    }
                    
                    String mappedField = mapCSVHeader(header);
                    
                    // Type conversion based on field type
                    if (mappedField == 'screeningPassThreshold') {
                        // Percent field - store as decimal
                        jobData.put(mappedField, Decimal.valueOf(value));
                    } else if (mappedField == 'enableScreening' || mappedField == 'autoRouteApproved') {
                        // Checkbox fields - convert to boolean
                        String lowerValue = value.toLowerCase();
                        jobData.put(mappedField, lowerValue == 'true' || lowerValue == 'yes' || lowerValue == '1');
                    } else if (mappedField == 'candidatesScreened' || mappedField == 'activeRulesCount') {
                        // Number fields
                        jobData.put(mappedField, Integer.valueOf(value));
                    } else if (mappedField == 'averagePassRate') {
                        // Percent field
                        jobData.put(mappedField, Decimal.valueOf(value));
                    } else if (mappedField == 'startDate' || mappedField == 'endDate') {
                        // Date fields - keep as string, will be parsed later
                        jobData.put(mappedField, value);
                    } else {
                        // Text and Picklist fields
                        jobData.put(mappedField, value);
                    }
                }
                
                jobPostings.add(jobData);
            }
            
            System.debug('Parsed ' + jobPostings.size() + ' job postings from CSV');
            
        } catch (Exception e) {
            System.debug('Error parsing CSV: ' + e.getMessage());
            throw new CSVParseException('Error parsing CSV: ' + e.getMessage());
        }
        
        return jobPostings;
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
        
        // Add the last field
        result.add(currentField.trim());
        
        return result;
    }
    
    // Map CSV headers to field names - ALL FIELDS
    private static String mapCSVHeader(String header) {
        Map<String, String> headerMapping = new Map<String, String>{
            // Name (Text 80)
            'name' => 'name',
            'job posting name' => 'name',
            'job name' => 'name',
            'title' => 'name',
            'job title' => 'name',
            'position' => 'name',
            
            // Category (Picklist)
            'category' => 'category',
            'department' => 'category',
            'function' => 'category',
            
            // Location (Text 255)
            'location' => 'location',
            'city' => 'location',
            'office' => 'location',
            
            // Experience Level (Picklist)
            'experience level' => 'experienceLevel',
            'experience' => 'experienceLevel',
            'level' => 'experienceLevel',
            
            // Specialization (Picklist)
            'specialization' => 'specialization',
            'specialty' => 'specialization',
            'role type' => 'specialization',
            
            // Description (Long Text Area)
            'description' => 'description',
            'job description' => 'description',
            'details' => 'description',
            
            // Status (Picklist)
            'status' => 'status',
            
            // Start Date (Date)
            'start date' => 'startDate',
            'startdate' => 'startDate',
            'opening date' => 'startDate',
            
            // End Date (Date)
            'end date' => 'endDate',
            'enddate' => 'endDate',
            'closing date' => 'endDate',
            
            // Enable Screening (Checkbox)
            'enable screening' => 'enableScreening',
            'screening' => 'enableScreening',
            'enable_screening' => 'enableScreening',
            
            // Screening Pass Threshold (Percent)
            'screening pass threshold' => 'screeningPassThreshold',
            'pass threshold' => 'screeningPassThreshold',
            'threshold' => 'screeningPassThreshold',
            
            // Auto Route Approved (Checkbox)
            'auto route approved' => 'autoRouteApproved',
            'auto route' => 'autoRouteApproved',
            'auto_route_approved' => 'autoRouteApproved',
            
            // Default Journey Path (Picklist)
            'default journey path' => 'defaultJourneyPath',
            'journey path' => 'defaultJourneyPath',
            
            // Candidates Screened (Number)
            'candidates screened' => 'candidatesScreened',
            'screened' => 'candidatesScreened',
            
            // Active Rules Count (Number)
            'active rules count' => 'activeRulesCount',
            'rules count' => 'activeRulesCount',
            
            // Average Pass Rate (Percent)
            'average pass rate' => 'averagePassRate',
            'pass rate' => 'averagePassRate'
        };
        
        String mappedHeader = headerMapping.get(header);
        return mappedHeader != null ? mappedHeader : header.replaceAll(' ', '');
    }
    
    // Create job postings from parsed CSV data
    public static List<String> createJobPostingsFromCSV(List<Map<String, Object>> jobDataList) {
        List<String> createdIds = new List<String>();
        List<String> errors = new List<String>();
        
        for (Integer i = 0; i < jobDataList.size(); i++) {
            try {
                Map<String, Object> jobData = jobDataList[i];
                String jobId = AIJobPostingService.createJobPosting(jobData);
                createdIds.add(jobId);
            } catch (Exception e) {
                String errorMsg = 'Row ' + (i + 2) + ': ' + e.getMessage();
                errors.add(errorMsg);
                System.debug('Error creating job posting for row ' + (i + 2) + ': ' + e.getMessage());
            }
        }
        
        if (!errors.isEmpty() && createdIds.isEmpty()) {
            // All rows failed
            throw new CSVParseException('All rows failed: ' + String.join(errors, '; '));
        } else if (!errors.isEmpty()) {
            // Some rows failed
            System.debug('Partial success. Errors: ' + String.join(errors, '; '));
        }
        
        return createdIds;
    }
    
    // Custom exception class
    public class CSVParseException extends Exception {}
}