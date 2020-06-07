
SELECT
	CUST_ID,
	SEG_NAME,
	UPDATED_AT
FROM
	(
	SELECT
		cust_id, seg_name, update_at AS UPDATED_AT, ROW_NUMBER() OVER (PARTITION BY CUST_ID
	ORDER BY
		UPDATE_AT DESC) AS LATEST
	FROM
		SEGMENTS
	WHERE
		ACTIVE_FLAG = 'Y' ) LATEST_SEG
WHERE
	LATEST = 1
-- ORDER BY
	-- UPDATED_AT ASC




SELECT * FROM SEGMENTS WHERE CUST_ID='12064' AND ACTIVE_FLAG='Y';

-- For each product purchased between Jan 2016 and May 2016 (inclusive), find
-- the number of distinct transactions

SELECT T.prod_id, P.prod_name, COUNT(distinct trans_id) 
FROM 
TRANSACTIONS T 
INNER JOIN PRODUCTS P ON 
P.PROD_ID=T.prod_id
WHERE T.trans_dt >= '2016-01-01 00:00:00' AND T.trans_dt<'2016-06-01 00:00:00'
GROUP BY T.prod_id, P.prod_name
ORDER BY COUNT(distinct trans_id) DESC;

SELECT * FROM transactions WHERE PROD_ID='138262084'
ORDER BY TRANS_DT;

--Find the most recent segment of each customer as of 2016-03-01
select * from segments;

create view Cust_seg_view as 
SELECT cust_id, seg_name, update_at
FROM(
SELECT cust_id, seg_name, update_at, 
ROW_NUMBER () OVER (PARTITION BY cust_id ORDER BY update_at DESC) LATEST
FROM (
SELECT 
cust_id, seg_name, update_at
FROM 
SEGMENTS 
WHERE update_at<='2016-03-01 00:00:00' 
)PER_SEG
)FINAL WHERE LATEST=1
--ORDER BY update_at;
;

SELECT cust_id, COUNT(*) FROM (
SELECT * FROM Cust_seg_view 
)DUPS GROUP BY cust_id
HAVING COUNT(*)>1

--VERIFICATION AGAINST SAMPLE RESULTS SENT
SELECT * FROM Cust_seg_view WHERE CUST_ID IN (4402,11248,126169) --MATCHES WITH THE SAMPLE DATA SET SENT

-- FIND MOST POPULAR CATEGORY FOR EACH ACTIVE SEGMENT. READ AS MOST REVENUE PRODUCING WHERE REVENUE IS item_qty* item_price

-- BELOW GIVES THE REVENUE PER SEGMENT AND CATEGORY.
SELECT
S.seg_name,
P.category,
SUM(T.item_price * T.item_qty) AS REVENUE
FROM 
TRANSACTIONS T 
INNER JOIN products P ON 
P.prod_id=T.prod_id
INNER JOIN segments S ON 
S.CUST_ID =T.cust_id
WHERE S.ACTIVE_FLAG='Y'
GROUP BY S.seg_name, P.category
ORDER BY REVENUE DESC;

-- TO GET THE MOST REVENUE PRODUCING CATEGORY PER ACTIVE SEGMENT 
SELECT SEG_NAME, category, REVENUE FROM 
(
SELECT SEG_NAME, CATEGORY, REVENUE,
RANK() OVER(PARTITION BY SEG_NAME ORDER BY REVENUE DESC) AS MOST_POP
FROM
(
SELECT
S.seg_name,
P.category,
SUM(T.item_price * T.item_qty) AS REVENUE
FROM 
TRANSACTIONS T 
INNER JOIN products P ON 
P.prod_id=T.prod_id
INNER JOIN segments S ON 
S.CUST_ID =T.cust_id
WHERE S.ACTIVE_FLAG='Y'
GROUP BY S.seg_name, P.category
--ORDER BY REVENUE DESC;
)MOST_POP 
)FINAL WHERE MOST_POP=1
ORDER BY REVENUE DESC;


-- TO CHECK IF WE ARE ACCOUNTING FOR ALL ACTIVE segments
SELECT DISTINCT SEG_NAME FROM SEGMENTS WHERE active_flag='Y' ; --6 segments

-- TO CHECK IF WE HAVE TRANSACTIONS FOR SEGMENTS THAT ARE NOT SHOWING IN THE REVENUE PRODUCING POPULAR category
SELECT T.* FROM TRANSACTIONS T
INNER JOIN segments S ON 
S.cust_id=T.cust_id
WHERE seg_name='INACTIVE' AND ACTIVE_FLAG='Y';
-- 0 RECORDS. WHICH MEANS THAT THERE ARE NO TRANSACTIONS WHERE SEG_NAME =INACTIVE AND SEG IS active_flag


-- LEAST POPULAR CATEGORIES PER ACTIVE segments
SELECT SEG_NAME, category, REVENUE FROM 
(
SELECT SEG_NAME, CATEGORY, REVENUE,
RANK() OVER(PARTITION BY SEG_NAME ORDER BY REVENUE ASC) AS MOST_POP
FROM
(
SELECT
S.seg_name,
P.category,
SUM(T.item_price * T.item_qty) AS REVENUE
FROM 
TRANSACTIONS T 
INNER JOIN products P ON 
P.prod_id=T.prod_id
INNER JOIN segments S ON 
S.CUST_ID =T.cust_id
WHERE S.ACTIVE_FLAG='Y'
GROUP BY S.seg_name, P.category
--ORDER BY REVENUE DESC;
)MOST_POP 
)FINAL WHERE MOST_POP=1
ORDER BY REVENUE DESC;



































