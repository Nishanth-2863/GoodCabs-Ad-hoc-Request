select * from dim_city;
select * from dim_date;
select * from dim_repeat_trip_distribution;
select * from fact_passenger_summary;
select * from fact_trips;
--  SET SESSION sql_mode = (SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));


-- Q1

with city_level_fare as (
Select city_name,count(trip_id) as total_trips,round(sum(fare_amount)/sum(distance_travelled_km),2)  as avg_per_km,
round(avg(fare_amount),2) as avg_fare_per_trip  from dim_city c
join fact_trips ft on c.city_id=ft.city_id
group by city_name
)

select *,round(total_trips/sum(total_trips) over()*100,2) as pct_contribute_to_total_trips from city_level_fare order by pct_contribute_to_total_trips desc;


/*

2.
*/

SET SESSION sql_mode = (SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));

with actual_trip as (
select c.city_id,city_name,monthname(date) as monthName,count(trip_id) as actual_trips from dim_city c 
join  fact_trips ft on c.city_id=ft.city_id
group by city_name,monthname(date)
)
select city_name,monthName,actual_trips,total_target_trips,
case
when actual_trips<=total_target_trips then 'Below Target'
else 'Above Target'
end as Performance_status,((actual_trips-total_target_trips)/total_target_trips*100) as diff_pct
from actual_trip act
join targets_db.monthly_target_trips mtt on act.city_id=mtt.city_id and act.monthName=monthname(mtt.month);


-- 3. 


SELECT 	c.city_name,
    ROUND(SUM(CASE WHEN trip_count = '2-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '2-Trips%',
    ROUND(SUM(CASE WHEN trip_count = '3-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '3-Trips%',
    ROUND(SUM(CASE WHEN trip_count = '4-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '4-Trips%',
    ROUND(SUM(CASE WHEN trip_count = '5-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '5-Trips%',
    ROUND(SUM(CASE WHEN trip_count = '6-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '6-Trips%',
    ROUND(SUM(CASE WHEN trip_count = '7-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '7-Trips%',
    ROUND(SUM(CASE WHEN trip_count = '8-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '8-Trips%',
    ROUND(SUM(CASE WHEN trip_count = '9-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '9-Trips%',
    ROUND(SUM(CASE WHEN trip_count = '10-Trips' THEN repeat_passenger_count else 0 END) / sum(repeat_passenger_count) * 100, 2)  AS '10-Trips%'
FROM 
    dim_repeat_trip_distribution  r_trips
JOIN dim_city c on c.city_id = r_trips.city_id
GROUP BY 
    c.city_name;






-- 4.
with new_passenger_report as (
select city_name,sum(new_passengers) as total_new_passengers from dim_city c 
join  fact_passenger_summary  fps on fps.city_id=c.city_id
group by city_name
), ranked_cities as (
select *,rank() over(order by total_new_passengers desc) as city_rank  from new_passenger_report
)
select *,
case 
when city_rank <=3 then 'Top 3' 
when city_rank >=(select max(city_rank)-2  from ranked_cities) then  'bottom 3' 
else city_rank
end as city_category
from ranked_cities;



-- 5.
with ranking_month_wise_revenue as (
select *,row_number() over(partition by city_name order by revenue_mln desc) as revenue_rn,
sum(revenue_mln) over(partition by city_name) as total_revenue
 from (
select city_name,month_name,round(sum(fare_amount)/100000,2) as revenue_mln from fact_trips f_trips
join  dim_date d_date on f_trips.date=d_date.date
join dim_city d_city on d_city.city_id=f_trips.city_id
group by city_name,month_name
) as x
)
 SELECT city_name,
    month_name AS highest_revenue_month,
    revenue_mln,
    round((revenue_mln / total_revenue)* 100,2) AS percentage_contribution
    FROM ranking_month_wise_revenue
    WHERE revenue_rn = 1;
    
-- 6.
with month_wise as (
select city_name,month_name,sum(repeat_passengers) as total_repeat_passenger,
sum(total_passengers) as total_passengers from fact_passenger_summary fps
join dim_date d_date on fps.month=d_date.date
join dim_city dc on dc.city_id=fps.city_id
group by city_name,month_name
),
city_wise as (
select city_name,sum(total_repeat_passenger) as 
city_wise_repeat_passenger,sum(total_passengers) as city_wise_total_passenger from month_wise
group by city_name
)

select cw.city_name,month_name,total_repeat_passenger,total_passengers,
round((total_repeat_passenger/total_passengers*100),2) as monthly_repeat_passenger_rate, 
round((city_wise_repeat_passenger/city_wise_total_passenger*100),2) as city_repeat_passenger_rate
from month_wise
mw join city_wise cw on mw.city_name=cw.city_name
order by city_repeat_passenger_rate desc;


