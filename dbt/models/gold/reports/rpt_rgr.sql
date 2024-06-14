WITH unique_customers AS (
    SELECT DISTINCT IF(Customer IS NULL, 'null', Customer) AS Fulcrum_ID
    FROM {{ source("Operations_Master_Datasets", "Manual_MRR") }}
),

account AS (
    SELECT
        sf_acc.Account_ID,
        sf_acc.IsTopParent,
        sf_acc.Top_Parent_Account_ID__c,
        sf_acc.Fulcrum_ID,
        sf_acc.Top_Parent_Account_Name__c,
        sf_acc.Account_Name,
        sf_acc.ZoomInfo_Company_Revenue__c,
        sf_acc.Zoominfo_Employee_Count_Number__c,
        sf_acc.Account_Owner,
        sf_acc.Owner_s_Manager__c,
        sf_acc.ZoomInfo_Industry__c,
        sf_acc.X18_Digit_Account_ID__c,
        sf_acc.Market__c
    FROM {{ ref("rpt_accounts") }} AS sf_acc
    WHERE Fulcrum_ID IS NOT NULL
),

accounthistory AS (
    SELECT
        acc_h.AccountId,
        acc_h.OldValue AS PreviousAccountOwner,
        EXTRACT(DATE FROM DATETIME(TIMESTAMP(acc_h.CreatedDate), 'America/Los_Angeles')) AS LastAccountOwnerChange,
        ROW_NUMBER() OVER (PARTITION BY acc_h.AccountId ORDER BY acc_h.CreatedDate DESC) AS rn
    FROM {{ ref("salesforce_accounthistory") }} AS acc_h
    WHERE
        Field = 'Owner'
),

full_account AS (
    SELECT
        sf_acc.Account_ID,
        sf_acc.IsTopParent,
        sf_acc.Top_Parent_Account_ID__c,
        sf_acc.Fulcrum_ID,
        sf_acc.Top_Parent_Account_Name__c,
        sf_acc.Account_Name,
        sf_acc.ZoomInfo_Company_Revenue__c,
        sf_acc.Zoominfo_Employee_Count_Number__c,
        sf_acc.Account_Owner,
        sf_acc.Owner_s_Manager__c,
        sf_acc.ZoomInfo_Industry__c,
        sf_acc.X18_Digit_Account_ID__c,
        sf_acc.Market__c,
        acc_h.LastAccountOwnerChange,
        acc_h.PreviousAccountOwner
    FROM account AS sf_acc
    LEFT JOIN accounthistory AS acc_h
        ON
            sf_acc.Account_ID = acc_h.AccountId
            AND acc_h.rn = 1
),

max_month AS (
    SELECT CAST(MAX(Month) AS DATE) AS CurrentMonth
    FROM {{ source("Operations_Master_Datasets", "Manual_MRR") }}
    WHERE
        Month IS NOT NULL
        AND Customer != 'Ops Test'
),

hw_this_month_license AS (
    SELECT
        IF(mrr.Customer IS NULL, 'null', mrr.Customer) AS Fulcrum_ID,
        COALESCE(MAX(CASE
            WHEN
                mrr.Month BETWEEN COALESCE(GREATEST(
                    DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 11 MONTH),
                    CAST(acc.LastAccountOwnerChange AS DATE)
                ), DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 11 MONTH))
                AND (SELECT CurrentMonth FROM max_month)
                THEN mrr.Mrr
            ELSE 0
        END), 0) AS HighWaterMarkThisMonthLicense
    FROM {{ source("Operations_Master_Datasets", "Manual_MRR") }} AS mrr
    LEFT JOIN full_account AS acc
        ON mrr.Customer = acc.Fulcrum_ID
    GROUP BY
        1
),

hw_this_month_msp AS (
    SELECT
        IF(mrr.Customer IS NULL, 'null', mrr.Customer) AS Fulcrum_ID,
        COALESCE(MAX(CASE
            WHEN
                mrr.Month BETWEEN COALESCE(GREATEST(
                    DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 11 MONTH),
                    CAST(acc.LastAccountOwnerChange AS DATE)
                ), DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 11 MONTH))
                AND (SELECT CurrentMonth FROM max_month)
                THEN mrr.Mrr
            ELSE 0
        END), 0) AS HighWaterMarkThisMonthMSP
    FROM {{ source("Operations_Master_Datasets", "Manual_MSP") }} AS mrr
    LEFT JOIN full_account AS acc
        ON mrr.Customer = acc.Fulcrum_ID
    GROUP BY
        1
),

hw_last_month_license AS (
    SELECT
        IF(mrr.Customer IS NULL, 'null', mrr.Customer) AS Fulcrum_ID,
        COALESCE(MAX(CASE
            WHEN
                mrr.Month BETWEEN COALESCE(GREATEST(
                    DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 12 MONTH),
                    CAST(acc.LastAccountOwnerChange AS DATE)
                ), DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 12 MONTH))
                AND DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 1 MONTH)
                THEN mrr.Mrr
            ELSE 0
        END), 0) AS HighWaterMarkLastMonthLicense
    FROM {{ source("Operations_Master_Datasets", "Manual_MRR") }} AS mrr
    LEFT JOIN full_account AS acc
        ON mrr.Customer = acc.Fulcrum_ID
    GROUP BY
        1
),

hw_last_month_msp AS (
    SELECT
        IF(mrr.Customer IS NULL, 'null', mrr.Customer) AS Fulcrum_ID,
        COALESCE(MAX(CASE
            WHEN
                mrr.Month BETWEEN COALESCE(GREATEST(
                    DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 12 MONTH),
                    CAST(acc.LastAccountOwnerChange AS DATE)
                ), DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 12 MONTH))
                AND DATE_SUB((SELECT CurrentMonth FROM max_month), INTERVAL 1 MONTH)
                THEN mrr.Mrr
            ELSE 0
        END), 0) AS HighWaterMarkLastMonthMSP
    FROM {{ source("Operations_Master_Datasets", "Manual_MSP") }} AS mrr
    LEFT JOIN full_account AS acc
        ON mrr.Customer = acc.Fulcrum_ID
    GROUP BY
        1
),

msp AS (
    SELECT *
    FROM (
        SELECT
            MRR,
            Month,
            IF(Customer IS NULL, 'null', Customer) AS Customer
        FROM {{ source("Operations_Master_Datasets", "Manual_MSP") }}
    )
    PIVOT
    (
        SUM(MRR) AS msp
        FOR LEFT(CAST(Month AS STRING), 7) IN (
            "{{ generate_months_list(2022, 1, 2024, 1) | join('", "') }}"
        )
    )
),

rgr AS (
    SELECT *
    FROM (
        SELECT
            MRR,
            Month,
            IF(Customer IS NULL, 'null', Customer) AS Customer
        FROM {{ source("Operations_Master_Datasets", "Manual_MRR") }}
    )
    PIVOT
    (
        SUM(MRR) AS rgr
        FOR LEFT(CAST(Month AS STRING), 7) IN (
            "{{ generate_months_list(2022, 1, 2024, 1) | join('", "') }}"
        )
    )
)

SELECT
    acc.Account_ID,
    acc.IsTopParent,
    acc.Top_Parent_Account_ID__c,
    uc.Fulcrum_ID,
    acc.Top_Parent_Account_Name__c,
    acc.Account_Name,
    acc.ZoomInfo_Company_Revenue__c,
    acc.Zoominfo_Employee_Count_Number__c,
    acc.Account_Owner,
    acc.Owner_s_Manager__c,
    acc.ZoomInfo_Industry__c,
    acc.LastAccountOwnerChange,
    acc.PreviousAccountOwner,
    acc.X18_Digit_Account_ID__c,
    acc.Market__c,
    COALESCE(hw_lm_lic.HighWaterMarkLastMonthLicense, 0) AS HighWaterMarkLastMonthLicense,
    COALESCE(hw_lm_msp.HighWaterMarkLastMonthMSP, 0) AS HighWaterMarkLastMonthMSP,
    COALESCE(hw_lm_lic.HighWaterMarkLastMonthLicense, 0) + COALESCE(hw_lm_msp.HighWaterMarkLastMonthMSP, 0) AS HighWaterMarkLastMonthTotal,
    COALESCE(hw_tm_lic.HighWaterMarkThisMonthLicense, 0) AS HighWaterMarkThisMonthLicense,
    COALESCE(hw_tm_msp.HighWaterMarkThisMonthMSP, 0) AS HighWaterMarkThisMonthMSP,
    COALESCE(hw_tm_lic.HighWaterMarkThisMonthLicense, 0) + COALESCE(hw_tm_msp.HighWaterMarkThisMonthMSP, 0) AS HighWaterMarkThisMonthTotal,
    {% for month in generate_months_list(2022, 1, 2024, 1) %}
        COALESCE(`rgr_{{ month }}`, 0) AS `rgr_{{ month }}`,
        COALESCE(`msp_{{ month }}`, 0) AS `msp_{{ month }}`,
        COALESCE(`msp_{{ month }}`, 0) + COALESCE(`rgr_{{ month }}`, 0)
            AS `total_{{ month }}`,
    {% endfor %}
    {% for month in generate_months_list(2022, 1, 2024, 1)[-13:] %}
        COALESCE(`rgr_{{ month }}`, 0) AS `rgr_{{ loop.revindex0 }}`,
        COALESCE(`msp_{{ month }}`, 0) AS `msp_{{ loop.revindex0 }}`,
        COALESCE(`msp_{{ month }}`, 0) + COALESCE(`rgr_{{ month }}`, 0)
            AS `total_{{ loop.revindex0 }}`,
    {% endfor %}
FROM unique_customers AS uc
LEFT JOIN hw_this_month_license AS hw_tm_lic
    ON uc.Fulcrum_ID = hw_tm_lic.Fulcrum_ID
LEFT JOIN hw_last_month_license AS hw_lm_lic
    ON uc.Fulcrum_ID = hw_lm_lic.Fulcrum_ID
LEFT JOIN hw_this_month_msp AS hw_tm_msp
    ON uc.Fulcrum_ID = hw_tm_msp.Fulcrum_ID
LEFT JOIN hw_last_month_msp AS hw_lm_msp
    ON uc.Fulcrum_ID = hw_lm_msp.Fulcrum_ID
LEFT JOIN full_account AS acc
    ON uc.Fulcrum_ID = acc.Fulcrum_ID
LEFT JOIN msp
    ON uc.Fulcrum_ID = msp.Customer
LEFT JOIN rgr
    ON uc.Fulcrum_ID = rgr.Customer
