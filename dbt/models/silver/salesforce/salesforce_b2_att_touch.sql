WITH max_date AS (
    SELECT max(substr(run_date, 1, 8)) AS max_date
    FROM {{ source('sni_salesforce_history',  'bizible2__Bizible_Attribution_Touchpoint__c') }}
),

source AS (
    SELECT s.* FROM {{ source('sni_salesforce_history',  'bizible2__Bizible_Attribution_Touchpoint__c') }} AS s
    INNER JOIN max_date
        ON substr(s.run_date, 1, 8) = max_date.max_date
),

renamed AS (
    SELECT
        cast(
            json_value(json_data.bizible2__Attribution_Custom_Model_2__c) AS FLOAT64
        ) AS bizible2__Attribution_Custom_Model_2__c,
        cast(
            json_value(json_data.bizible2__Attribution_Custom_Model__c) AS FLOAT64
        ) AS bizible2__Attribution_Custom_Model__c,
        cast(json_value(json_data.bizible2__Attribution_First_Touch__c) AS FLOAT64)
            AS bizible2__Attribution_First_Touch__c,
        cast(json_value(json_data.bizible2__Attribution_Lead_Conversion_Touch__c) AS FLOAT64)
            AS bizible2__Attribution_Lead_Conversion_Touch__c,
        cast(json_value(json_data.bizible2__Attribution_U_Shaped__c) AS FLOAT64) AS bizible2__Attribution_U_Shaped__c,
        cast(json_value(json_data.bizible2__Attribution_W_Shaped__c) AS FLOAT64) AS bizible2__Attribution_W_Shaped__c,
        cast(json_value(json_data.bizible2__Count_Custom_Model_2__c) AS FLOAT64) AS bizible2__Count_Custom_Model_2__c,
        cast(json_value(json_data.bizible2__Count_Custom_Model__c) AS FLOAT64) AS bizible2__Count_Custom_Model__c,
        cast(json_value(json_data.bizible2__Count_First_Touch__c) AS INT64) AS bizible2__Count_First_Touch__c,
        cast(json_value(json_data.bizible2__Count_Lead_Creation_Touch__c) AS INT64)
            AS bizible2__Count_Lead_Creation_Touch__c,
        cast(json_value(json_data.bizible2__Count_U_Shaped__c) AS FLOAT64) AS bizible2__Count_U_Shaped__c,
        cast(json_value(json_data.bizible2__Count_W_Shaped__c) AS FLOAT64) AS bizible2__Count_W_Shaped__c,
        cast(json_value(json_data.bizible2__Revenue_Custom_Model_2__c) AS FLOAT64)
            AS bizible2__Revenue_Custom_Model_2__c,
        cast(json_value(json_data.bizible2__Revenue_Custom_Model__c) AS FLOAT64) AS bizible2__Revenue_Custom_Model__c,
        cast(json_value(json_data.bizible2__Revenue_First_Touch__c) AS FLOAT64) AS bizible2__Revenue_First_Touch__c,
        cast(json_value(json_data.bizible2__Revenue_Lead_Conversion__c) AS FLOAT64)
            AS bizible2__Revenue_Lead_Conversion__c,
        cast(json_value(json_data.bizible2__Revenue_U_Shaped__c) AS FLOAT64) AS bizible2__Revenue_U_Shaped__c,
        cast(json_value(json_data.bizible2__Revenue_W_Shaped__c) AS FLOAT64) AS bizible2__Revenue_W_Shaped__c,
        json_value(json_data.Id) AS Id,
        json_value(json_data.OwnerId) AS OwnerId,
        json_value(json_data.IsDeleted) AS IsDeleted,
        json_value(json_data.Name) AS Name_c,
        date(json_value(json_data.Createddate)) AS date_Createddate,
        datetime(timestamp(json_value(json_data.Createddate)), "America/Los_Angeles") AS Createddate,
        json_value(json_data.CreatedById) AS CreatedById,
        date(json_value(json_data.LastModifieddate)) AS date_LastModifieddate,
        datetime(timestamp(json_value(json_data.LastModifieddate)), "America/Los_Angeles") AS LastModifieddate,
        json_value(json_data.LastModifiedById) AS LastModifiedById,
        date(json_value(json_data.SystemModstamp)) AS date_SystemModstamp,
        datetime(timestamp(json_value(json_data.SystemModstamp)), "America/Los_Angeles") AS SystemModstamp,
        json_value(json_data.bizible2__Account__c) AS bizible2__Account__c,
        json_value(json_data.bizible2__Ad_Campaign_Id__c) AS bizible2__Ad_Campaign_Id__c,
        json_value(json_data.bizible2__Ad_Campaign_Name__c) AS bizible2__Ad_Campaign_Name__c,
        json_value(json_data.bizible2__Ad_Content__c) AS bizible2__Ad_Content__c,
        json_value(json_data.bizible2__Ad_Destination_URL__c) AS bizible2__Ad_Destination_URL__c,
        json_value(json_data.bizible2__Ad_Group_Id__c) AS bizible2__Ad_Group_Id__c,
        json_value(json_data.bizible2__Ad_Group_Name__c) AS bizible2__Ad_Group_Name__c,
        json_value(json_data.bizible2__Ad_Id__c) AS bizible2__Ad_Id__c,
        json_value(json_data.bizible2__Browser__c) AS bizible2__Browser__c,
        json_value(json_data.bizible2__Contact__c) AS bizible2__Contact__c,
        json_value(json_data.bizible2__Form_URL_Raw__c) AS bizible2__Form_URL_Raw__c,
        json_value(json_data.bizible2__Form_URL__c) AS bizible2__Form_URL__c,
        json_value(json_data.bizible2__Geo_City__c) AS bizible2__Geo_City__c,
        json_value(json_data.bizible2__Geo_Country__c) AS bizible2__Geo_Country__c,
        json_value(json_data.bizible2__Geo_Region__c) AS bizible2__Geo_Region__c,
        json_value(json_data.bizible2__Keyword_Id__c) AS bizible2__Keyword_Id__c,
        json_value(json_data.bizible2__Keyword_MatchType__c) AS bizible2__Keyword_MatchType__c,
        json_value(json_data.bizible2__Keyword_Text__c) AS bizible2__Keyword_Text__c,
        json_value(json_data.bizible2__Landing_Page_Raw__c) AS bizible2__Landing_Page_Raw__c,
        json_value(json_data.bizible2__Landing_Page__c) AS bizible2__Landing_Page__c,
        json_value(json_data.bizible2__Marketing_Channel_Path__c) AS bizible2__Marketing_Channel_Path__c,
        json_value(json_data.bizible2__Marketing_Channel__c) AS bizible2__Marketing_Channel__c,
        json_value(json_data.bizible2__Medium__c) AS bizible2__Medium__c,
        json_value(json_data.bizible2__Opportunity__c) AS bizible2__Opportunity__c,
        json_value(json_data.bizible2__Placement_Id__c) AS bizible2__Placement_Id__c,
        json_value(json_data.bizible2__Placement_Name__c) AS bizible2__Placement_Name__c,
        json_value(json_data.bizible2__Platform__c) AS bizible2__Platform__c,
        json_value(json_data.bizible2__Referrer_Page_Raw__c) AS bizible2__Referrer_Page_Raw__c,
        json_value(json_data.bizible2__Referrer_Page__c) AS bizible2__Referrer_Page__c,
        json_value(json_data.bizible2__SF_Campaign__c) AS bizible2__SF_Campaign__c,
        json_value(json_data.bizible2__Search_Phrase__c) AS bizible2__Search_Phrase__c,
        json_value(json_data.bizible2__Segment__c) AS bizible2__Segment__c,
        json_value(json_data.bizible2__Site_Id__c) AS bizible2__Site_Id__c,
        json_value(json_data.bizible2__Site_Name__c) AS bizible2__Site_Name__c,
        date(json_value(json_data.bizible2__Touchpoint_date__c)) AS date_bizible2__Touchpoint_date__c,
        datetime(timestamp(json_value(json_data.bizible2__Touchpoint_date__c)), "America/Los_Angeles")
            AS bizible2__Touchpoint_date__c,
        json_value(json_data.bizible2__Touchpoint_Position__c) AS bizible2__Touchpoint_Position__c,
        json_value(json_data.bizible2__Touchpoint_Source__c) AS bizible2__Touchpoint_Source__c,
        json_value(json_data.bizible2__Touchpoint_Type__c) AS bizible2__Touchpoint_Type__c,
        json_value(json_data.bizible2__UniqueId__c) AS bizible2__UniqueId__c,
        json_value(json_data.bizible2__Form_Name__c) AS bizible2__Form_Name__c,
        json_value(json_data.bizible2__User_Touchpoint_Id__c) AS bizible2__User_Touchpoint_Id__c,
        substr(run_date, 1, 8) AS run_date
    FROM source
)

SELECT * FROM renamed
