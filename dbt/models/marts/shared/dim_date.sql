-- Calendrier des années civiles 2016 à 2018 : couvre toutes les dates des faits
-- (achat, approbation, livraison jusqu'au 2018-10-17, livraison estimée jusqu'au 2018-10-25).
with

calendar as (

    select day
    from unnest(generate_date_array(date '2016-01-01', date '2018-12-31', interval 1 day)) as day

),

final as (

    select
        day as date_day,
        extract(year from day) as year_number,
        extract(quarter from day) as quarter_number,
        extract(month from day) as month_number,
        format_date('%B', day) as month_name,
        format_date('%Y-%m', day) as year_month,
        extract(day from day) as day_of_month,
        extract(dayofweek from day) as day_of_week_number,
        format_date('%A', day) as day_of_week_name,
        extract(dayofweek from day) in (1, 7) as is_weekend

    from calendar

)

select * from final
