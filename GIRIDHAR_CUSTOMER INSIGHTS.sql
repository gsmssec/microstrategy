-- How Many Infrequent, One-off or new Customers are we able to convert to Loyal or VIP customers? CUSTOMER RETENTION TRENDS
-- When are we able to do that? During off season- or holiday season when we are pushing promotions and deals?
-- What do Loyal and VIP customers usually buy?
-- What do other customer segments usually buy?

-- TOTAL NUMBER OF CUSTOMERS EACH SEGMENT
select
	SEG_NAME,
	COUNT(CUST_ID)
from
	segments
where
	ACTIVE_FLAG = 'Y'
group by
	SEG_NAME
order by
	COUNT(CUST_ID) desc;

-- TOTAL CUSTOMERS THAT HAVE CHANGED SEGMENT
select
	CUST_ID,
	COUNT(distinct SEG_NAME)
from
	segments
group by
	CUST_ID
having
	COUNT(distinct SEG_NAME)>1;

-- LOOK at CUSTOMERS THAT are in THE ACTIVE SEGMENT and where THE SEGMENT HAS CHANGED from OTHER THAN LOYAL and VIP
-- get all vip and loyal customer subset


create or replace
view sample.v_active_cust_segments_VIP_LYL as
select
	cust_id,
	seg_name,
	update_at,
	active_flag
from
	( (
	select
		cust_id, seg_name, update_at, active_flag, row_number() over(partition by cust_id
	order by
		update_at desc) latest
	from
		segments
	where
		active_flag = 'Y'
		and seg_name in ('VIP', 'LOYAL') ) )finl
where
	latest = 1 ;

select
	count(1)
from
	sample.v_active_cust_segments_VIP_LYL;

-- get all non vip and NON- loyal customers subset FOR INACTIVE SEGMENTS
create or replace
view sample.v_inactive_cust_segments as
select
	cust_id,
	seg_name,
	update_at,
	active_flag
from
	( (
	select
		cust_id, seg_name, update_at, active_flag, row_number() over(partition by cust_id
	order by
		update_at desc) latest
	from
		segments
	where
		active_flag = 'N'
		and seg_name not in ('VIP', 'LOYAL') ) )finl
where
	latest = 1 ;

-- GET ALL NON VIP AND NON- LOYAL CUSTOMERS SUBSET ALL INCLUSIVE(ON ACTIVE FLAG)
create or replace
view sample.v_nonLV_cust_segments_ALL as
select
	cust_id,
	seg_name,
	update_at,
	active_flag
from
	( (
	select
		cust_id, seg_name, update_at, active_flag, row_number() over(partition by cust_id
	order by
		update_at desc) latest
	from
		segments
	where
		seg_name not in ('VIP', 'LOYAL') ) )finl
where
	latest = 1 ;

select
	*
from
	sample.v_inactive_cust_segments;

/*-----------------------------------------------------------------------------------------------------------------------*/
-- QUESTION -- -- How Many Infrequent, One-off or new Customers are we able to 
-- convert to Loyal or VIP customers? CUSTOMER RETENTION TRENDS
/*-----------------------------------------------------------------------------------------------------------------------*/
create or replace
view sample.v_cust_retention_gain as
select
	ACV.CUST_ID,
	ACV.SEG_NAME as CURRENT_SEGMENT,
	IACV.SEG_NAME as PREVIOUS_SEGMENT
from
	sample.v_active_cust_segments_VIP_LYL ACV
inner join sample.v_inactive_cust_segments IACV on
	ACV.CUST_ID = IACV.CUST_ID
where
	ACV.UPDATE_AT >= IACV.UPDATE_AT
order by
	IACV.SEG_NAME;
-- ADDED WHERE CONDITION ACV.UPDATE_AT >= IACV.UPDATE_AT
-- THIS IS TO MAKE SURE WE ARE NOT TAKING CUSTOMER THAT HAVE GONE FROM ACTIVE TO INACTIVE
select distinct CUST_ID from sample.v_cust_retention_gain
-- 200


-- CUSTOMERS WE HAVE NOT BEEN ABLE TO RETAIN
create or replace
view sample.v_cust_retention_loss as
select
	COUNT(distinct VIP_LOYAL.cust_id ) COUNT_CUST_ID
from
	SEGMENTS VIP_LOYAL 
	inner join SEGMENTS OTHER on 
	VIP_LOYAL.cust_id = OTHER.cust_id 
where
	VIP_LOYAL.ACTIVE_FLAG='N' and 
	VIP_LOYAL.seg_name in ('VIP','LOYAL') and 
	OTHER.SEG_NAME not in ('VIP','LOYAL') and
	OTHER.update_at > VIP_LOYAL.update_at 
;
-- 252 
select * from sample.v_cust_retention_loss

-- CUSTOMER WE HAVE TO TARGET FOR RETENTION
create or replace
view sample.v_cust_retention_target as
select
	COUNT(1)
from
	sample.v_nonLV_cust_segments_ALL
where
	CUST_ID not in (
	select CUST_ID from SAMPLE.v_active_cust_segments_VIP_LYL
);

/*-----------------------------------------------------------------------------------------------------------------------*/
-- question -- -- When are we able to do that? During off season
-- or holiday season when we are pushing promotions and deals?
/*-----------------------------------------------------------------------------------------------------------------------*/
-- customer retention trends -- when are we able to do that?
-- get the update_dt of customers that we have been able to retain
create view SAMPLE.V_CUST_RETN_TRENDS AS
select
	ACV.CUST_ID,
	ACV.SEG_NAME as CURRENT_SEGMENT,
	IACV.SEG_NAME as PREVIOUS_SEGMENT,
	acv.update_at as Date_converted
from
	sample.v_active_cust_segments ACV
inner join sample.v_inactive_cust_segments IACV on
	ACV.CUST_ID = IACV.CUST_ID
where
	ACV.UPDATE_AT >= IACV.UPDATE_AT
order by
	ACV.update_at;

-- TO CHECK WHEN WE HAVE MAX CONVERSIONS AND LEAST CONVERSIONS.
select
	DATE_CONVERTED,
	COUNT(1)
from
	SAMPLE.V_CUST_RETN_TRENDS
group by
	DATE_CONVERTED
order by
	COUNT(1) asc;

-- MAX CONVERSIONS DURING FEBRUARY AND LEAST DURING MARCH AND APRIL
-- THE PREVIOUS YEARS DATA IS TOO SMALL FOR A QUANTITATIVE COMPARISON

/*-----------------------------------------------------------------------------------------------------------------------*/
-- CUSTOMER BUYING TRENDS ACROSS VIP/LOYAL CUSTOMERS AND NON-CUSTOMERS.(OTHER SEGMENTS)
-- What do Loyal and VIP customers usually buy?
-- what do other segments usually buy?
/*-----------------------------------------------------------------------------------------------------------------------*/
create OR replace view SAMPLE.V_ACTIVE_CUST_SEGMENTS AS
SELECT
	CUST_ID,
	SEG_NAME,
	UPDATED_AT,
	active_flag 
FROM
	(
	SELECT
		cust_id, seg_name, update_at AS UPDATED_AT,ACTIVE_FLAG, ROW_NUMBER() OVER (PARTITION BY CUST_ID
	ORDER BY
		UPDATE_AT DESC) AS LATEST
	FROM
		SEGMENTS
	WHERE
		ACTIVE_FLAG = 'Y' ) LATEST_SEG
WHERE
	LATEST = 1;
-- ORDER BY
	-- UPDATED_AT ASC
	
-- create a view that hosts the total data from the join on transactions, segments and products
create or replace
view sample.v_all_inclusive as
select
	t.trans_id,
	t.trans_dt,
	t.item_qty,
	t.item_price,
	p.prod_id,
	p.prod_name,
	p.brand,
	p.category,
	s.cust_id,
	s.seg_name,
	s.UPDATED_AT as update_AT,
	s.active_flag
from
	transactions t
inner join V_ACTIVE_CUST_SEGMENTS s on
	s.cust_id = t.cust_id
inner join products p on
	p.prod_id = t.prod_id ;


-- buying trends per segments
select
	seg_name,
	category,
	count(1)
from
	v_all_inclusive
group by
	1,
	2
order by
	category;

/*-----------------------------------------------------------------------------------------------------------------------*/
-- CUSTOMER BUYING TRENDS Based on PRODUCT BRANDS
-- Best Selling Brands
/*-----------------------------------------------------------------------------------------------------------------------*/

-- Are there any prod changes? on brand?
select
	prod_name,
	count(1)
from
	sample.products p
group by
	prod_name
having
	count(1)>1;

-- are there any Price changes on products
create or replace
view SAMPLE.V_PROD_PRICE_CHANGES as
select
	prod_id,
	prod_name,
	brand,
	count(distinct item_price) as Change_count
from
	(
	select
		prod_name, p.brand, p.prod_id, (t.item_price / t.item_qty) as item_price
	from
		sample.products p
	inner join transactions t on
		t.prod_id = p.prod_id )prc
group by
	prod_id,
	prod_name,
	brand
having
	count(distinct item_price)>1
order by
	count(distinct item_price);

select * from SAMPLE.V_PROD_PRICE_CHANGES;

-- FIND THE MOST POPULAR BRANDS SOLD
select
	p.brand,
	P.CATEGORY, 
	SUM(t.item_qty)
from
	sample.products p
inner join transactions t on
	t.prod_id = p.prod_id
group by
	brand,
	CATEGORY
order by
	BRAND, SUM(t.item_qty) desc;


/*-----------------------------------------------------------------------------------------------------------------------*/
-- Increase in sales if infrequent and one-off converted to loyal or VIP ACROSS ACTIVE SEGMENTS
/*-----------------------------------------------------------------------------------------------------------------------*/

-- HOW DO THE REGULAR CUSTOMERS COMPARE OVER OTHER CUSTOMER(INFREQUENT, ONEOFF ETC)?
create view SAMPLE.V_AVG_CUST_SALES_BY_SEG as
select
	SEGMENT,
	TOTAL_REVENUE,
	TOTAL_CUSTOMERS,
	TOTAL_REVENUE / TOTAL_CUSTOMERS as AVG_PER_CUST
from
	(
	select
		SEGMENT, SUM(REVENUE) as TOTAL_REVENUE, COUNT(CUST_ID) as TOTAL_CUSTOMERS
	from
		(
		select
			case
				when SEG_NAME in ('LOYAL', 'VIP') then 'REGULAR'
				when SEG_NAME not in ('LOYAL', 'VIP') then 'OTHER'
			end as SEGMENT, ITEM_QTY*ITEM_PRICE as REVENUE, CUST_ID
		from
			sample.v_all_inclusive
		where
			ACTIVE_FLAG = 'Y' )TOTAL
	group by
		SEGMENT ) AVG_SALES;

create or replace view SAMPLE.V_AVG_CUST_SALES_SEG_REG as
select * from SAMPLE.V_AVG_CUST_SALES_BY_SEG 
where SEGMENT = 'REGULAR'; 

create or replace view SAMPLE.V_AVG_CUST_SALES_SEG_OTHER as
select * from SAMPLE.V_AVG_CUST_SALES_BY_SEG 
where SEGMENT <> 'REGULAR'; 

-- HOW DO THE VIP CUSTOMERS COMPARE OVER LOYAL CUSTOMER?
create view SAMPLE.V_AVG_CUST_SALES_BY_REGULARS as
select
	SEGMENT,
	TOTAL_REVENUE,
	TOTAL_CUSTOMERS,
	TOTAL_REVENUE / TOTAL_CUSTOMERS as AVG_PER_CUST
from
	(
	select
		SEGMENT, SUM(REVENUE) as TOTAL_REVENUE, COUNT(CUST_ID) as TOTAL_CUSTOMERS
	from
		(
		select
			SEG_NAME as SEGMENT, ITEM_QTY*ITEM_PRICE as REVENUE, CUST_ID
		from
			sample.v_all_inclusive
		where
			ACTIVE_FLAG = 'Y'
			and SEG_NAME in ('LOYAL', 'VIP') )TOTAL
	group by
		SEGMENT ) AVG_SALES;
		
create or replace view SAMPLE.V_AVG_CUST_SALES_SEG_VIP as
select * from SAMPLE.V_AVG_CUST_SALES_BY_REGULARS 
where SEGMENT = 'VIP'; 

create or replace view SAMPLE.V_AVG_CUST_SALES_SEG_LOYAL as
select * from SAMPLE.V_AVG_CUST_SALES_BY_REGULARS 
where SEGMENT = 'LOYAL'; 

select * from SAMPLE.V_AVG_CUST_SALES_SEG_VIP;
select * from SAMPLE.V_AVG_CUST_SALES_SEG_LOYAL;


select COUNT( CUST_ID) from segments s 