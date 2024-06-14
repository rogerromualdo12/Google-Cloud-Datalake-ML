SELECT
    acc.Id AS Account_ID,
    acc.Top_Parent_Account_ID__c,
    acc.X18_Digit_Account_ID__c,
    acc.Fulcrum_ID__c AS Fulcrum_ID,
    acc.Name AS Account_Name,
    acc.Top_Parent_Account_Name__c,
    sf_user.Name AS Account_Owner,
    acc.Owner_s_Manager__c,
    acc.ZoomInfo_Company_Revenue__c,
    acc.Zoominfo_Employee_Count_Number__c,
    acc.ZoomInfo_Industry__c,
    acc.Market__c,
    acc.Monthly_Revenue__c,
    IF(acc.Top_Parent_Account_ID__c = acc.Id, "Yes", "No") AS IsTopParent,
    CAST(DATETIME(TIMESTAMP(acc.CreatedDate), "America/Los_Angeles") AS DATE) AS CreatedDate
FROM {{ ref('salesforce_account') }} AS acc
INNER JOIN {{ ref('salesforce_user') }} AS sf_user
    ON acc.OwnerId = sf_user.Id
