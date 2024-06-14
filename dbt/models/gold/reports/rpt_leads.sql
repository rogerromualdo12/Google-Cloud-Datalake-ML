SELECT
    lead.Id AS Lead_ID,
    sf_user.Name AS Owner_Name,
    lead.Ful__c,
    lead.ConvertedAccountId,
    lead.ConvertedContactId,
    lead.ConvertedOpportunityId,
    lead.IsConverted,
    lead.ConvertedDate,
    lead.FirstName,
    lead.LastName,
    lead.Email,
    lead.Company,
    lead.Status,
    lead.MQL_Reason__c,
    lead.Account_Tier__c,
    lead.Buyer_Persona__c,
    lead.Industry,
    lead.LeadSource,
    lead.FT_Lead_Source__c,
    lead.FT_Lead_Source_Channel__c,
    lead.FT_Lead_Source_Detail__c,
    lead.LT_Lead_Source__c,
    lead.LT_Lead_Source_Channel__c,
    lead.LT_Lead_Source_Detail__c,
    lead.GBQ_Reporting_Lead__c,
    lead.SDR_Assisted__c,
    lead.Lead_Source_Category__c,
    EXTRACT(DATE FROM DATETIME(TIMESTAMP(lead.CreatedDate), "America/Los_Angeles")) AS CreatedDate
FROM {{ ref("salesforce_lead") }} AS lead
INNER JOIN {{ ref("salesforce_user") }} AS sf_user
    ON lead.OwnerId = sf_user.Id
WHERE lead.GBQ_Reporting_Lead__c = True
