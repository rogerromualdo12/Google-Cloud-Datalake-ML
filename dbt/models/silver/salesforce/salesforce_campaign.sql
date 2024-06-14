WITH max_date AS (
    SELECT max(substr(run_date, 1, 8)) AS max_date
    FROM {{ source('sni_salesforce_history',  'Campaign') }}
),

source AS (
    SELECT s.* FROM {{ source('sni_salesforce_history',  'Campaign') }} AS s
    INNER JOIN max_date
        ON substr(s.run_date, 1, 8) = max_date.max_date
),

renamed AS (
    SELECT
        Id,
        json_value(json_data.ActualCost) AS ActualCost,
        json_value(json_data.AmountAllOpportunities) AS AmountAllOpportunities,
        json_value(json_data.AmountWonOpportunities) AS AmountWonOpportunities,
        json_value(json_data.BudgetedCost) AS BudgetedCost,
        json_value(json_data.CampaignMemberRecordTypeId) AS CampaignMemberRecordTypeId,
        json_value(json_data.CreatedById) AS CreatedById,
        json_value(json_data.CreatedDate) AS CreatedDate,
        json_value(json_data.Description) AS Description,
        json_value(json_data.EndDate) AS EndDate,
        json_value(json_data.ExpectedResponse) AS ExpectedResponse,
        json_value(json_data.ExpectedRevenue) AS ExpectedRevenue,
        json_value(json_data.HierarchyActualCost) AS HierarchyActualCost,
        json_value(json_data.HierarchyAmountAllOpportunities) AS HierarchyAmountAllOpportunities,
        json_value(json_data.HierarchyAmountWonOpportunities) AS HierarchyAmountWonOpportunities,
        json_value(json_data.HierarchyBudgetedCost) AS HierarchyBudgetedCost,
        json_value(json_data.HierarchyExpectedRevenue) AS HierarchyExpectedRevenue,
        json_value(json_data.HierarchyNumberOfContacts) AS HierarchyNumberOfContacts,
        json_value(json_data.HierarchyNumberOfConvertedLeads) AS HierarchyNumberOfConvertedLeads,
        json_value(json_data.HierarchyNumberOfLeads) AS HierarchyNumberOfLeads,
        json_value(json_data.HierarchyNumberOfOpportunities) AS HierarchyNumberOfOpportunities,
        json_value(json_data.HierarchyNumberOfResponses) AS HierarchyNumberOfResponses,
        json_value(json_data.HierarchyNumberOfWonOpportunities) AS HierarchyNumberOfWonOpportunities,
        json_value(json_data.HierarchyNumberSent) AS HierarchyNumberSent,
        json_value(json_data.IsActive) AS IsActive,
        json_value(json_data.IsDeleted) AS IsDeleted,
        json_value(json_data.LastActivityDate) AS LastActivityDate,
        json_value(json_data.LastModifiedById) AS LastModifiedById,
        json_value(json_data.LastModifiedDate) AS LastModifiedDate,
        json_value(json_data.LastReferencedDate) AS LastReferencedDate,
        json_value(json_data.LastViewedDate) AS LastViewedDate,
        json_value(json_data.LeanData__Back_Dated__c) AS LeanData__Back_Dated__c,
        json_value(json_data.LeanData__Rep_LT_Attribution__c) AS LeanData__Rep_LT_Attribution__c,
        json_value(json_data.LeanData__Rep_LT_Bookings_Attribution__c) AS LeanData__Rep_LT_Bookings_Attribution__c,
        json_value(json_data.LeanData__Rep_LT_Generated_Attribution__c) AS LeanData__Rep_LT_Generated_Attribution__c,
        json_value(json_data.LeanData__Rep_LT_Generated_Bookings_Attribution__c)
            AS LeanData__Rep_LT_Generated_Bookings_Attribution__c,
        json_value(json_data.LeanData__Rep_MT_Accelerated_Attribution__c)
            AS LeanData__Rep_MT_Accelerated_Attribution__c,
        json_value(json_data.LeanData__Rep_MT_Accelerated_Bookings_Attr__c)
            AS LeanData__Rep_MT_Accelerated_Bookings_Attr__c,
        json_value(json_data.LeanData__Rep_MT_Generated_Attribution__c) AS LeanData__Rep_MT_Generated_Attribution__c,
        json_value(json_data.LeanData__Rep_MT_Generated_Bookings_Attribution__c)
            AS LeanData__Rep_MT_Generated_Bookings_Attribution__c,
        json_value(json_data.LeanData__Reporting_Average_Days_To_Close__c)
            AS LeanData__Reporting_Average_Days_To_Close__c,
        json_value(json_data.LeanData__Reporting_Bookings_Attribution__c)
            AS LeanData__Reporting_Bookings_Attribution__c,
        json_value(json_data.LeanData__Reporting_Campaign_Member_Totals__c)
            AS LeanData__Reporting_Campaign_Member_Totals__c,
        json_value(json_data.LeanData__Reporting_Cost__c) AS LeanData__Reporting_Cost__c,
        json_value(json_data.LeanData__Reporting_FT_Attribution_Amount__c)
            AS LeanData__Reporting_FT_Attribution_Amount__c,
        json_value(json_data.LeanData__Reporting_FT_Bookings_Attribution__c)
            AS LeanData__Reporting_FT_Bookings_Attribution__c,
        json_value(json_data.LeanData__Reporting_Lift__c) AS LeanData__Reporting_Lift__c,
        json_value(json_data.LeanData__Reporting_MT_Attribution_Amount__c)
            AS LeanData__Reporting_MT_Attribution_Amount__c,
        json_value(json_data.LeanData__Reporting_Num_Target_Campaign_Members__c)
            AS LeanData__Reporting_Num_Target_Campaign_Members__c,
        json_value(json_data.LeanData__Reporting_Number_Of_Campaign_Members__c)
            AS LeanData__Reporting_Number_Of_Campaign_Members__c,
        json_value(json_data.LeanData__Reporting_Number_Of_Opportunities__c)
            AS LeanData__Reporting_Number_Of_Opportunities__c,
        json_value(json_data.LeanData__Reporting_Number_Of_Touches__c) AS LeanData__Reporting_Number_Of_Touches__c,
        json_value(json_data.LeanData__Reporting_On_Target__c) AS LeanData__Reporting_On_Target__c,
        json_value(json_data.LeanData__Reporting_Opportunity_Close_Rate__c)
            AS LeanData__Reporting_Opportunity_Close_Rate__c,
        json_value(json_data.Name) AS CampaignName,
        json_value(json_data.NumberOfContacts) AS NumberOfContacts,
        json_value(json_data.NumberOfConvertedLeads) AS NumberOfConvertedLeads,
        json_value(json_data.NumberOfLeads) AS NumberOfLeads,
        json_value(json_data.NumberOfOpportunities) AS NumberOfOpportunities,
        json_value(json_data.NumberOfResponses) AS NumberOfResponses,
        json_value(json_data.NumberOfWonOpportunities) AS NumberOfWonOpportunities,
        json_value(json_data.NumberSent) AS NumberSent,
        json_value(json_data.OwnerId) AS OwnerId,
        json_value(json_data.ParentId) AS ParentId,
        json_value(json_data.StartDate) AS StartDate,
        json_value(json_data.Status) AS CampaignStatus,
        json_value(json_data.SystemModstamp) AS SystemModstamp,
        json_value(json_data.Type) AS CampaignType,
        json_value(json_data.bizible2__Bizible_Attribution_SyncType__c) AS bizible2__Bizible_Attribution_SyncType__c,
        json_value(json_data.bizible2__Touchpoint_End_Date__c) AS bizible2__Touchpoint_End_Date__c,
        json_value(json_data.bizible2__Touchpoint_Start_Date__c) AS bizible2__Touchpoint_Start_Date__c,
        json_value(json_data.bizible2__UniqueId__c) AS bizible2__UniqueId__c,
        substr(run_date, 1, 8) AS run_date
    FROM source
)

SELECT * FROM renamed
