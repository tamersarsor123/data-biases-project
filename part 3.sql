-----מטלה 1

SELECT
    p.Name AS Product_Name,
    p.Base_Price,
    c.Category_Name,
    AVG(CAST(r.Rating AS FLOAT)) AS Average_Rating,
    COUNT(r.Review_ID) AS Number_of_Reviews
FROM PRODUCT p
JOIN CATEGORY c
    ON c.Category_ID = p.Category_ID
JOIN REVIEW r
    ON r.Product_ID = p.Product_ID
WHERE p.Base_Price > 0
GROUP BY
    p.Product_ID, p.Name, p.Base_Price, c.Category_Name
ORDER BY
    Average_Rating DESC;



SELECT
    P.Name AS Product_Name,
    P."Base_Price",
    AVG(R.Rating) AS Average_Rating,
    COUNT(R."Review_ID") AS Number_of_Reviews
FROM "PRODUCT" P
JOIN "REVIEW" R
    ON P."Product_ID" = R."Product_ID"
GROUP BY
    P."Product_ID",
    P.Name,
    P."Base_Price"
ORDER BY
    Average_Rating DESC;




SELECT
    p.Product_ID,
    p.Name AS Product_Name,
    p.Base_Price,
    CASE
        WHEN p.Base_Price <= (
            SELECT MIN(Base_Price) +
                   (MAX(Base_Price) - MIN(Base_Price)) /3
            FROM PRODUCT
        ) THEN 'Low'

        WHEN p.Base_Price <= (
            SELECT MIN(Base_Price) +
                   2 * (MAX(Base_Price) - MIN(Base_Price))/3 
            FROM PRODUCT
        ) THEN 'Medium'

        ELSE 'High'
    END AS Price_Order_Of_Magnitude
FROM PRODUCT p;



SELECT
    p.Product_ID,
    p.Name AS Product_Name,
    p.Base_Price,
    (
        SELECT c.Category_Name
        FROM dbo.CATEGORY c
        WHERE c.Category_ID = p.Category_ID
    ) AS Category_Name,
    (
        SELECT AVG(CAST(r.Rating AS float))
        FROM dbo.REVIEW r
        WHERE r.Product_ID = p.Product_ID
    ) AS Avg_Rating
FROM dbo.PRODUCT p;

SELECT
    x.Category_ID,
    x.Category_Name,
    x.Product_ID,
    x.Product_Name,
    x.Avg_Rating,
    x.Reviews_Count,
    RANK() OVER (
        PARTITION BY x.Category_ID
        ORDER BY x.Avg_Rating DESC, x.Reviews_Count DESC
    ) AS Rank_In_Category,
    NTILE(4) OVER (
        PARTITION BY x.Category_ID
        ORDER BY x.Avg_Rating DESC, x.Reviews_Count DESC
    ) AS Rating_Quartile_In_Category
FROM (
    SELECT
        c.Category_ID,
        c.Category_Name,
        p.Product_ID,
        p.Name AS Product_Name,
        AVG(CAST(r.Rating AS float)) AS Avg_Rating,
        COUNT(*) AS Reviews_Count
    FROM CATEGORY c
    JOIN PRODUCT p ON p.Category_ID = c.Category_ID
    JOIN REVIEW r  ON r.Product_ID = p.Product_ID
    GROUP BY c.Category_ID, c.Category_Name, p.Product_ID, p.Name
) x
ORDER BY x.Category_Name, Rank_In_Category;



SELECT
    t.Customer_ID,
    t.First_Name,
    t.Last_Name,
    t.Order_ID,
    t.OrderDate,
    t.PaidOrdersCount,
    NTILE(4) OVER (ORDER BY t.PaidOrdersCount DESC) AS Activity_Quartile
FROM (
    SELECT
        cu.Customer_ID,
        r.First_Name,
        r.Last_Name,
        o.Order_ID,
        o.OrderDate,
        COUNT(*) OVER (PARTITION BY cu.Customer_ID) AS PaidOrdersCount
    FROM [ORDER] o
    JOIN CART ca       ON ca.Cart_ID = o.Cart_ID
    JOIN CUSTOMER cu   ON cu.Customer_ID = ca.Customer_ID
    JOIN REGISTERED r  ON r.Customer_ID = cu.Customer_ID
    WHERE o.PaymentStatus = 'Paid'
) AS t
ORDER BY Activity_Quartile, t.PaidOrdersCount DESC, t.Customer_ID, t.OrderDate;



WITH
AllProducts AS (
    SELECT
        p.Product_ID,
        p.Name AS Product_Name,
        p.Base_Price,
        p.Category_ID
    FROM PRODUCT p
),
GlobalPriceStats AS (
    SELECT
        AVG(CAST(ap.Base_Price AS float)) AS Global_Avg_Price,
        MIN(ap.Base_Price) AS Global_Min_Price,
        MAX(ap.Base_Price) AS Global_Max_Price
    FROM AllProducts ap
),
Final AS (
    SELECT
        c.Category_Name,
        ap.Product_ID,
        ap.Product_Name,
        ap.Base_Price,
        gps.Global_Avg_Price,
        (CAST(ap.Base_Price AS float) - gps.Global_Avg_Price) AS Deviation_From_Global_Avg,
        RANK() OVER (ORDER BY ap.Base_Price DESC) AS Global_Price_Rank,
        NTILE(4) OVER (ORDER BY ap.Base_Price DESC) AS Global_Price_Quartile,
        CASE
            WHEN ap.Base_Price <= gps.Global_Min_Price + (gps.Global_Max_Price - gps.Global_Min_Price) / 3.0 THEN 'Low'
            WHEN ap.Base_Price <= gps.Global_Min_Price + 2.0 * (gps.Global_Max_Price - gps.Global_Min_Price) / 3.0 THEN 'Medium'
            ELSE 'High'
        END AS Global_Price_Band
    FROM AllProducts ap
    CROSS JOIN GlobalPriceStats gps
    JOIN CATEGORY c ON c.Category_ID = ap.Category_ID
)
SELECT 
    Category_Name,
    Product_ID,
    Product_Name,
    Base_Price,
    Global_Avg_Price,
    Deviation_From_Global_Avg,
    Global_Price_Rank,
    Global_Price_Quartile,
    Global_Price_Band
FROM Final
ORDER BY Base_Price DESC;







-----שיפור 

WITH ReviewPerProduct AS (
    SELECT
        r.Product_ID,
        AVG(CAST(r.Rating AS FLOAT)) AS AvgRatingPerProduct
    FROM REVIEW r
    GROUP BY r.Product_ID
)
SELECT
    c.Category_ID,
    c.Category_Name,
    AVG(rpp.AvgRatingPerProduct) AS AvgRating
FROM CATEGORY c
JOIN PRODUCT p
    ON p.Category_ID = c.Category_ID
JOIN ReviewPerProduct rpp
    ON rpp.Product_ID = p.Product_ID
GROUP BY
    c.Category_ID,
    c.Category_Name
ORDER BY
    AvgRating DESC;


    WITH ReviewAgg AS (
    SELECT
        r.Product_ID,
        AVG(CAST(r.Rating AS FLOAT)) AS Average_Rating,
        COUNT(*) AS Number_of_Reviews
    FROM REVIEW r
    GROUP BY r.Product_ID
)
SELECT
    p.Name AS Product_Name,
    p.Base_Price,
    c.Category_Name,
    ra.Average_Rating,
    ra.Number_of_Reviews
FROM PRODUCT p
JOIN CATEGORY c
    ON c.Category_ID = p.Category_ID
JOIN ReviewAgg ra
    ON ra.Product_ID = p.Product_ID
WHERE p.Base_Price > 0
ORDER BY
    ra.Average_Rating DESC;



    ----מטלה 2 


CREATE OR ALTER VIEW dbo.vw_OrderHealthCheck
AS
SELECT
    o.Order_ID,
    c.Customer_ID,
    o.Cart_ID,
    o.OrderDate,
    o.TotalAmount,
    o.PaymentStatus,
    o.shipping_status,

    -- Payment risk
    CASE
        WHEN o.PaymentStatus IN ('Failed') THEN 'PAYMENT_HIGH_RISK'
        WHEN o.PaymentStatus IN ('Refunded') THEN 'PAYMENT_MEDIUM_RISK'
        WHEN o.PaymentStatus IN ('Pending') THEN 'PAYMENT_WAITING'
        WHEN o.PaymentStatus IN ('Paid') THEN 'PAYMENT_OK'
        ELSE 'PAYMENT_UNKNOWN'
    END AS PaymentFlag,

    -- Shipping risk
    CASE
        WHEN o.shipping_status IN ('not delverd') THEN 'SHIPPING_RISK'
        WHEN o.shipping_status IN ('deliverd') THEN 'SHIPPING_OK'
        ELSE 'SHIPPING_UNKNOWN'
    END AS ShippingFlag,

    -- Final decision for operations 
    CASE
        WHEN o.PaymentStatus IN ('Failed') THEN 'BLOCK_ORDER'
        WHEN o.PaymentStatus IN ('Refunded') THEN 'MANUAL_REVIEW'
        WHEN o.PaymentStatus IN ('Pending') THEN 'WAIT_PAYMENT'
        WHEN o.shipping_status IN ('not delverd') THEN 'SHIPMENT_FOLLOWUP'
        ELSE 'APPROVE'
    END AS ActionDecision,

    -- A simple score for prioritizing team work
    CAST(
        (CASE WHEN o.PaymentStatus IN ('Failed') THEN 5 ELSE 0 END)
      + (CASE WHEN o.PaymentStatus IN ('Refunded') THEN 3 ELSE 0 END)
      + (CASE WHEN o.PaymentStatus IN ('Pending') THEN 2 ELSE 0 END)
      + (CASE WHEN o.shipping_status IN ('not delverd') THEN 4 ELSE 0 END)
      + (CASE WHEN o.TotalAmount >= 500 THEN 2 ELSE 0 END)
    AS INT) AS OrderRiskScore

FROM dbo.[Order] o
JOIN dbo.Cart c
    ON c.Cart_ID = o.Cart_ID;
GO



CREATE OR ALTER FUNCTION dbo.fn_GetCustomerRiskScore
(
    @CustomerID INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Score DECIMAL(10,2);

    SELECT @Score = v.RiskScore
    FROM dbo.vw_CustomerTrustProfile AS v
    WHERE v.Customer_ID = @CustomerID;

    -- If customer not found in the view, return -1 
    RETURN ISNULL(@Score, -1);
END;
GO
SELECT dbo.fn_GetCustomerRiskScore(7) AS RiskScore;



CREATE OR ALTER FUNCTION dbo.fn_OrdersNeedingAttention
(
    @FromDate DATE,
    @ToDate   DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        o.Order_ID,
        TRY_CONVERT(date, o.OrderDate) AS OrderDate,
        o.Cart_ID,
        c.Customer_ID,
        o.TotalAmount,
        o.PaymentStatus,
        o.shipping_status,

        CASE WHEN o.PaymentStatus IN ('Failed','Refunded') THEN 1 ELSE 0 END AS IsPaymentRisk,
        CASE WHEN o.shipping_status IN ('not delverd','not delivered','not_delivered') THEN 1 ELSE 0 END AS IsShippingRisk,

        CASE
            WHEN o.PaymentStatus IN ('Failed','Refunded') THEN 'PAYMENT_ISSUE'
            WHEN o.shipping_status IN ('not delverd','not delivered','not_delivered') THEN 'SHIPPING_ISSUE'
            ELSE 'OK'
        END AS AttentionReason
    FROM dbo.[Order] o
    JOIN dbo.Cart c
        ON c.CartID = o.Cart_ID
    WHERE TRY_CONVERT(date, o.OrderDate) >= @FromDate
      AND TRY_CONVERT(date, o.OrderDate) <  DATEADD(DAY, 1, @ToDate)
      AND (
            o.PaymentStatus IN ('Failed','Refunded')
         OR o.shipping_status IN ('not delverd','not delivered','not_delivered')
      )
);
GO
SELECT *
FROM dbo.fn_OrdersNeedingAttention('2024-01-01', '2024-12-31')
ORDER BY OrderDate DESC;




IF COL_LENGTH('dbo.Cart','Last Updated') IS NULL
    ALTER TABLE dbo.Cart
    ADD Last_Updated DATETIME2 NULL;
GO
CREATE OR ALTER TRIGGER dbo.trg_UpdateCartLastUpdated
ON dbo.[Order]
AFTER INSERT, UPDATE
AS
BEGIN
    UPDATE c
    SET c.Last_Updated = SYSUTCDATETIME()
    FROM dbo.Cart c
    JOIN inserted i
        ON i.Cart_ID = c.Cart_ID;
END;
GO
SELECT TOP 15 Cart_ID, Last_Updated
FROM dbo.Cart
ORDER BY Cart_ID;
GO
UPDATE dbo.[Order]
SET PaymentStatus = 'Paid'
WHERE Order_ID IN
(
    SELECT TOP 1 o.Order_ID
    FROM dbo.[Order] o
    ORDER BY o.OrderDate DESC
);
GO
SELECT TOP 15 Cart_ID, Last_Updated
FROM dbo.Cart
ORDER BY Cart_ID;
GO
