--This script demonstrates usage of "crosstab" function. It transposes date from a column (insurance types) into several different columns. 
--This helps to define customer groups by their product composition. 
---------------------------------------------------
select 
count(distinct rgs_id)
from cdi.contract_agg as t1
where 1=1
and (t1.yyyymm=201805)
and (t1.bgn_dt between '2018-01-01' and '2018-05-31')

select 
*
from cdi.contract_agg as t1
where 1=1
and (t1.yyyymm=201805) 
and (t1.rgs_id='000065250244edce7306209430bea103')

SELECT * FROM crosstab(
   $$SELECT rgs_id, ins_type, con_id
	from cdi.contract_agg as t1
	where 1=1
	and (t1.yyyymm=201805) 
	and (t1.rgs_id='000065250244edce7306209430bea103')
	$$
   ) AS t (rgs_id varchar, ins_type varchar, con_id varchar);

SELECT EXTRACT (WEEK FROM CURRENT_DATE)

----

SELECT *
FROM   crosstab(
       'SELECT unnest(''{rgs_id, con_id, ins_type, bgn_dt, end_dt, con_region}''::text[]) AS col
             , row_number() OVER ()
             , unnest(ARRAY[rgs_id::text, con_id::text, ins_type::text, bgn_dt::text, end_dt::text, con_region::text]) AS val
        FROM   cdi.contract_agg as t1
       where t1.yyyymm=201805 
         and t1.rgs_id=''000065250244edce7306209430bea103''
       ORDER BY 1, 2'
   ) t (col text, r1 text ,r2 text, r3 text)

SELECT * FROM crosstab(
   $$SELECT rgs_id, ins_type, rn, con_id, ins_pay
     FROM  (
        SELECT u.rgs_id, u.ins_type, e.con_id, e.ins_pay
             , row_number() OVER (PARTITION BY u.rgs_id
                            ORDER BY e.ins_type DESC) AS rn
        FROM   (select 
				*
				from cdi.contract_agg as t1
				where 1=1
				and (t1.yyyymm=201805) 
				and (t1.rgs_id='000065250244edce7306209430bea103')
				) as u
        LEFT JOIN (select 
				*
				from cdi.contract_agg as t1
				where 1=1
				and (t1.yyyymm=201805) 
				and (t1.rgs_id='000065250244edce7306209430bea103')
				) e USING (rgs_id)
        ) sub
     WHERE  rn < 6
     ORDER  BY rgs_id
   $$
  , 'VALUES (1)'
   ) AS t (rgs_id text, ins_type text, con_id text, ins_pay int);

----
--drop view test1;
create view test1 as
(
select 
rgs_id
,ins_type
,ins_pay
from cdi.contract_agg as t1
where 1=1
and (t1.yyyymm=201805) 
and (t1.rgs_id='000065250244edce7306209430bea103')
);

SELECT *
FROM crosstab(
  'select rgs_id, ins_type
   from test1
   where ins_type = ''att2'' or ins_type = ''att3''
   order by 1,2')
AS ct(rgs_id text, category_1 text, category_2 text, category_3 text);

----
select * from temp_1 where id=1

select id, key::text, val::text
from temp_1
order by id, key
 
SELECT *
FROM crosstab(
    'select id, key::text, val::text
     from temp_1
     order by id, key'
) AS ct(id INT, first_name TEXT, last_name TEXT);

SELECT *
FROM crosstab(
    'select rgs_id, ins_type::text, ins_pay::int
     from test1
     order by rgs_id, ins_type::text'
) AS ct(rgs_id varchar, ins_type1 int, ins_type2 int, ins_type3 int, ins_type4 int, ins_type5 int);

SELECT *
FROM crosstab(
    'select rgs_id, ins_type::text, ins_type::text
     from test1
     order by rgs_id, ins_type::text'
) AS ct(rgs_id varchar, ins_type1 text, ins_type2 text, ins_type3 text, ins_type4 text, ins_type5 text);
---------------------------------------------------
--client base 201805
--transpose active clients
--drop view crm.space;
create view crm.space as 
(
select ' '
);

--drop view crm.from_dt;
create view crm.from_dt as 
(
select '2018-01-01' as from_dt
);

--drop view crm.to_dt;
create view crm.to_dt as 
(
select '2018-05-31' as to_dt
);

--transpose data
--drop table crm.osago_cross_1;
create table crm.osago_cross_1 as
(
SELECT *
FROM crosstab(
    'select distinct 	
			cast(bgn_week_num || (select * from crm.space) || rgs_id as varchar) as wn_rgs_id, 
			upper(ins_type)::text, upper(ins_type)::text
     from 
		(
			select
			t1.*
			,EXTRACT (WEEK FROM bgn_dt) as bgn_week_num
			from cdi.contract_agg as t1
			where 1=1
			and (t1.yyyymm=201805)
			and (t1.bgn_dt between (select cast(from_dt as date) from crm.from_dt) and (select cast(to_dt as date) from crm.to_dt))
		) as t1	
     order by cast(bgn_week_num || (select * from crm.space) || rgs_id as varchar), upper(ins_type)::text'
) AS ct(wn_rgs_id varchar, 
		ins_type1 text, ins_type2 text, ins_type3 text, ins_type4 text, ins_type5 text,
	   	ins_type6 text, ins_type7 text, ins_type8 text, ins_type9 text, ins_type10 text)
);

--create product groups
--drop table crm.osago_cross_2;
create table crm.osago_cross_2 as
(
select
substring(wn_rgs_id from 1 for position(' ' in wn_rgs_id)) as week_num
,substring(wn_rgs_id from position(' ' in wn_rgs_id)+1 for 100) as rgs_id
,concat(ins_type1,'&',ins_type2,'&',ins_type3,'&',ins_type4,'&',ins_type5
	   ,'&',ins_type6,'&',ins_type7,'&',ins_type8,'&',ins_type9,'&',ins_type10) as ins_type_gr
from crm.osago_cross_1 as t1
where 1=1
);

--clean product groups
--drop table crm.osago_cross_3;
create table crm.osago_cross_3 as
(
select week_num, rgs_id, ins_type_gr
,case 
	when (CHAR_LENGTH(ins_type_gr) - CHAR_LENGTH(REPLACE(ins_type_gr, '&', ''))) / CHAR_LENGTH('&') = 0 then 'моно продукт'
	when (CHAR_LENGTH(ins_type_gr) - CHAR_LENGTH(REPLACE(ins_type_gr, '&', ''))) / CHAR_LENGTH('&') = 1 then 'один кросс продукт'
	when (CHAR_LENGTH(ins_type_gr) - CHAR_LENGTH(REPLACE(ins_type_gr, '&', ''))) / CHAR_LENGTH('&') = 2 then 'два кросс продукта'
	when (CHAR_LENGTH(ins_type_gr) - CHAR_LENGTH(REPLACE(ins_type_gr, '&', ''))) / CHAR_LENGTH('&') = 3 then 'три кросс продукта'
	when (CHAR_LENGTH(ins_type_gr) - CHAR_LENGTH(REPLACE(ins_type_gr, '&', ''))) / CHAR_LENGTH('&') > 3 then '4+ кросс продукта'
	else 'error'
end as cross_cl
,case when ins_type_gr like '%ОСАГО%' then 'есть ОСАГО' else 'нет ОСАГО' end as osago_flg
from
(	
	select
	week_num
	,rgs_id
	,RTRIM(ins_type_gr, '&') as ins_type_gr
	from
	(
		select
		week_num
		,rgs_id
		,replace(ins_type_gr, '&&', '') as ins_type_gr
		from crm.osago_cross_2 as t1
		where 1=1
	) as t1
	where 1=1
) as t1
);

select
'2018' as bgn_dt_year
,week_num
,ins_type_gr
,cross_cl
,osago_flg
,count(distinct rgs_id) as cl_cnt
from crm.osago_cross_3 as t1
where 1=1
group by 
week_num
,ins_type_gr
,cross_cl
,osago_flg

select 
* 
from crm.osago_cross_2 as t1
where 1=1
and rgs_id='7f919e9deafbd7a86505f51d9e029140'

and ins_type_gr='ДМСЖИВОТНЫЕНС'










select
week_num
,cross_cl
,count(distinct rgs_id) as cl_cnt
from crm.osago_cross_3 as t1
where 1=1
group by week_num, 
cross_cl

			select
			count(distinct rgs_id) as cl_cnt
			from cdi.contract_agg as t1
			where 1=1
			and (t1.yyyymm=201805)
			and (t1.bgn_dt between (select cast(from_dt as date) from crm.from_dt) and (select cast(to_dt as date) from crm.to_dt))

select
count(distinct rgs_id) as cl_cnt
from crm.osago_cross_3 as t1

select sum(cl_cnt) from
(
	select
	--week_num
	--cross_cl
	count(distinct rgs_id) as cl_cnt
	from crm.osago_cross_3 as t1
	where 1=1
	--group by --week_num, 
	--cross_cl
) as t1


SELECT EXTRACT (WEEK FROM CURRENT_DATE)

select * from crm.osago_cross_1 as t1
where 1=1
and (t1.wn_rgs_id like '%000065250244edce7306209430bea103%')

select
rgs_id
,ins_type
,ins_pay
,EXTRACT (WEEK FROM bgn_dt) as bgn_week_num
,bgn_dt
from cdi.contract_agg as t1
where 1=1
and (t1.yyyymm=201805) 
--and (t1.rgs_id='000065250244edce7306209430bea103')
and (t1.rgs_id='001f1f3dd532a9f84e55fbcc6177c4bd')

---------------------------------------------------
--client base 201805
--osago rgs_id shortlist
--drop table crm.osago_cross_1;
create table crm.osago_cross_1 as
(
	select distinct
	t1.con_id
	,t1.ins_pay
	,t1.rgs_id
	,ROW_NUMBER() OVER (PARTITION BY t1.rgs_id ORDER BY t1.ins_pay DESC) AS rn_rub_os --where 1 = the most expensive
	
	from cdi.contract_agg as t1
	
	where 1=1
	and (t1.yyyymm=201805)
	and (t1.ins_type='ОСАГО')
	and (t1.bgn_dt between '2018-01-01' and '2018-05-31')
);
-------------------------------------------------------
select count(distinct rgs_id) from crm.osago_cross_1
where 1=1
-------------------------------------------------------
--join info
--drop table crm.osago_cross_2;
create table crm.osago_cross_2 as
(
select
t1.rgs_id

,t3.subject_federation_name
,t4.FST_BGN_CON_DT
,case 
	when t4.FST_BGN_CON_DT between '2018-05-01' and '2018-05-31' then 1
	else 0
end as first_time_client --in the report period
	
,t1.rn_rub_os
,case 
	when extract(month from t2.bgn_dt) in (10,11,12) then extract(year from t2.bgn_dt) || '_' || extract(month from t2.bgn_dt)
	else extract(year from t2.bgn_dt) || '_0' || extract(month from t2.bgn_dt) 
end as osago_yr_mn
,t1.con_id as osago_con_id
,t2.ins_pay as osago_pay

,case 
	when extract(month from t5.bgn_dt) in (10,11,12) then extract(year from t5.bgn_dt) || '_' || extract(month from t5.bgn_dt)
	else extract(year from t5.bgn_dt) || '_0' || extract(month from t5.bgn_dt) 
end as kasko_yr_mn
,t5.con_id as kasko_con_id
,t5.ins_pay as kasko_pay

,case 
	when extract(month from t6.bgn_dt) in (10,11,12) then extract(year from t6.bgn_dt) || '_' || extract(month from t6.bgn_dt)
	else extract(year from t6.bgn_dt) || '_0' || extract(month from t6.bgn_dt) 
end as ifl_yr_mn
,t6.con_id as ifl_con_id
,t6.ins_pay as ifl_pay
	
,case 
	when extract(month from t7.bgn_dt) in (10,11,12) then extract(year from t7.bgn_dt) || '_' || extract(month from t7.bgn_dt)
	else extract(year from t7.bgn_dt) || '_0' || extract(month from t7.bgn_dt) 
end as other_yr_mn	
,t7.con_id as other_con_id
,t7.ins_pay as other_pay
	
from crm.osago_cross_1 as t1

left join cdi.contract_agg as t2 --osago cross join
on t1.con_id=t2.con_id
and (t2.yyyymm=201805)
and (t2.ins_type='ОСАГО')
and (t2.bgn_dt between '2018-01-01' and '2018-05-31')
	
left join (select cast(subject_federation_code as integer) as sfc, subject_federation_name from cdi.subjectrf) as t3
on t2.con_region=t3.sfc

left join cdi.cl_agg as t4
on t1.rgs_id=t4.rgs_id
and (t4.yyyymm=201805)
	
left join cdi.contract_agg as t5 --kasko cross join
on t1.rgs_id=t5.rgs_id
and (t5.yyyymm=201805)
and (upper(t5.ins_type)='КАСКО')
and (t5.bgn_dt between '2018-01-01' and '2018-05-31')
	
left join cdi.contract_agg as t6 --ifl cross join
on t1.rgs_id=t6.rgs_id
and (t6.yyyymm=201805)
and (upper(t6.ins_type) in ('СТРОЕНИЯ','КВАРТИРЫ'))
and (t6.bgn_dt between '2018-01-01' and '2018-05-31')

left join cdi.contract_agg as t7 --other cross join
on t1.rgs_id=t7.rgs_id
and (t7.yyyymm=201805)
and (upper(t7.ins_type) not in ('СТРОЕНИЯ','КВАРТИРЫ','КАСКО','ОСАГО'))
and (t7.bgn_dt between '2018-01-01' and '2018-05-31')

where 1=1
and (t1.rgs_id is not null)
);
-------------------------------------------------------
select * from crm.osago_cross_2 order by rgs_id limit 1000
select * from cdi.cl_agg limit 1000

select count(distinct rgs_id) from crm.osago_cross_2
where 1=1
-------------------------------------------------------
--join info
--drop table crm.osago_cross_3;
create table crm.osago_cross_3 as
(
	select
	rgs_id
	,t1.yr_mn
	,t1.subject_federation_name
	,t1.first_time_client
	
	,t1.prod_nm as osago_prod_nm
	,count(distinct t1.con_id) as os_con_cnt --osago contract count
	,sum(t1.ins_pay) as os_con_sum --osago contract sum

	,t1.kasko_prod_nm
	,count(distinct t1.kasko_con_id) as ka_con_cnt --kasko cross contract count
	,sum(t1.kasko_pay) as ka_con_sum --kasko cross contract sum

	,t1.ifl_prod_nm
	,count(distinct t1.ifl_con_id) as ifl_con_cnt --ifl cross contract count
	,sum(t1.ifl_pay) as ifl_con_sum --ifl cross contract sum

	,t1.other_prod_nm
	,count(distinct t1.other_con_id) as other_con_cnt --ifl cross contract count
	,sum(t1.other_pay) as other_con_sum --ifl cross contract sum
	
	from crm.osago_cross_2 as t1
	where 1=1
	group by
	t1.rgs_id
	,t1.ins_type
	,t1.prod_nm
	,t1.yr_mn
	,t1.subject_federation_name
	,t1.first_time_client
	,t1.kasko_prod_nm
	,t1.ifl_prod_nm
	,t1.other_prod_nm
);
-------------------------------------------------------
select 
* 
from crm.osago_cross_3
order by rgs_id
limit 1000
-------------------------------------------------------
--join info
--drop table crm.osago_cross_4;
create table crm.osago_cross_4 as
(
	select 
	t1.*
	,case 
		when os_con_cnt=0 then '0'
		when os_con_cnt=1 then '1'
		when os_con_cnt=2 then '2'
		when os_con_cnt=3 then '3'
		when os_con_cnt>3 then 'over 3 osago'
		else 'error'
	end as os_cnt_gr
	
	,case 
		when ka_con_cnt=0 then '0'
		when ka_con_cnt=1 then '1'
		when ka_con_cnt=2 then '2'
		when ka_con_cnt=3 then '3'
		when ka_con_cnt>3 then 'over 3 kasko'
		else 'error'
	end as ka_cnt_gr
	
	,case 
		when ifl_con_cnt=0 then '0'
		when ifl_con_cnt=1 then '1'
		when ifl_con_cnt=2 then '2'
		when ifl_con_cnt=3 then '3'
		when ifl_con_cnt>3 then 'over 3 ifl'
		else 'error'
	end as ifl_cnt_gr
	
	,case 
		when other_con_cnt=0 then '0'
		when other_con_cnt=1 then '1'
		when other_con_cnt=2 then '2'
		when other_con_cnt=3 then '3'
		when other_con_cnt>3 then 'over 3 other'
		else 'error'
	end as other_cnt_gr
	
	from crm.osago_cross_3 as t1
	where 1=1
);
-------------------------------------------------------
select * from crm.osago_cross_4 limit 1000
-------------------------------------------------------
--join info
--drop table crm.osago_cross_5;
create table crm.osago_cross_5 as
(
	select distinct 
	os_cnt_gr || ka_cnt_gr || ifl_cnt_gr || other_cnt_gr as client_gr
	from crm.osago_cross_4
);
	
-------------------------------------------------------
--aggregate script
select 
t1.ins_type
,t1.prod_nm
,t1.yr_mn
,t1.subject_federation_name
,t1.first_time_client

,count(distinct t1.con_id) as os_con_cnt --osago contract count
,sum(t1.ins_pay) as os_con_sum --osago contract sum

,t1.kasko_prod_nm
,count(distinct t1.kasko_con_id) as ka_con_cnt --kasko cross contract count
,sum(t1.kasko_pay) as ka_con_sum --kasko cross contract sum

,t1.ifl_prod_nm
,count(distinct t1.ifl_con_id) as ifl_con_cnt --ifl cross contract count
,sum(t1.ifl_pay) as ifl_con_sum --ifl cross contract sum

,t1.other_prod_nm
,count(distinct t1.other_con_id) as other_con_cnt --ifl cross contract count
,sum(t1.other_pay) as other_con_sum --ifl cross contract sum

from crm.osago_cross_2 as t1

where 1=1

group by 
t1.ins_type
,t1.prod_nm
,t1.yr_mn
,t1.subject_federation_name
,t1.first_time_client
,t1.kasko_prod_nm
,t1.ifl_prod_nm
,t1.other_prod_nm

--------------------
select distinct upper(ins_type)
from cdi.contract_agg as t1
where (t1.yyyymm=201805)
--------------------



