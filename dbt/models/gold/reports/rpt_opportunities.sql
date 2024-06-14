WITH converted_date AS (
    SELECT
        lead.ConvertedOpportunityId,
        MIN(lead.ConvertedDate) AS Min_Converted_Date
    FROM {{ ref("salesforce_lead") }} AS lead
    WHERE ConvertedOpportunityId IS NOT NULL
    GROUP BY 1
),

lead_id AS (
    SELECT
        c_date.ConvertedOpportunityId AS COID,
        MAX(lead.Id) AS Max_Lead_ID
    FROM converted_date AS c_date
    INNER JOIN {{ ref("salesforce_lead") }} AS lead
        ON
            c_date.ConvertedOpportunityId = lead.ConvertedOpportunityId
            AND c_date.Min_Converted_Date = lead.ConvertedDate
    GROUP BY 1
)

SELECT
    opp.Account_Id__c AS Account_ID,
    opp.Fulcrum_ID__c AS Fulcrum_ID,
    opp.Id AS Opportunity_Id,
    opp.Invoice_Id__c,
    acc.Top_Parent_Account_ID__c,
    acc.Name AS Account_Name,
    acc.Top_Parent_Account_Name__c,
    opp.Name AS Opportunity_Name,
    opp.Partner_Name__c,
    opp.Partner_Type__c,
    opp.type,
    opp.Sales_Cycle_Days__c,
    opp.LeadSource,
    opp.FT_Lead_Source_Channel__c,
    opp.FT_Lead_Source_Detail__c,
    opp.Persona__c,
    opp.SDR_Assisted__c,
    opp.Lead_Source_Category__c,
    opp.CloseDate,
    opp.StageName,
    opp.MRR__c,
    managers.Name AS Opportunity_Owner_Manager,
    sf_user.Name AS Opportunity_Owner,
    RecordType.Name AS Record_Type_Name,
    acc.ZoomInfo_Company_Revenue__c,
    acc.Zoominfo_Employee_Count_Number__c,
    acc.ZoomInfo_Industry__c,
    acc.Market__c,
    lead_id.Max_Lead_ID AS Lead_ID_From_Converted_Lead,
    opp.Overall_Sales_Duration__c,
    opp.Opportunity_Category__c,
    IF(acc.Top_Parent_Account_ID__c = acc.Id, "Yes", "No") AS IsTopParent,
    EXTRACT(DATE FROM DATETIME(TIMESTAMP(opp.CreatedDate), "America/Los_Angeles")) AS Opportunity_CreatedDate
FROM {{ ref("salesforce_opportunity") }} AS opp
INNER JOIN {{ ref("salesforce_account") }} AS acc
    ON opp.AccountId = acc.Id
INNER JOIN sni_salesforce.RecordType AS RecordType
    ON opp.RecordTypeId = RecordType.Id
LEFT JOIN lead_id AS lead_id
    ON opp.Id = lead_id.COID
LEFT JOIN {{ ref("salesforce_user") }} AS sf_user
    ON opp.OwnerId = sf_user.Id
LEFT JOIN {{ ref("salesforce_user") }} AS managers
    ON sf_user.ManagerId = managers.Id
