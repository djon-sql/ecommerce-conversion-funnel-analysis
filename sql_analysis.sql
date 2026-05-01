WITH base AS (
  SELECT
    user_pseudo_id,
    event_name,
    event_timestamp,
    geo.country AS country,
    traffic_source,
    device,

    -- витягнули один раз
    (SELECT value.int_value
     FROM UNNEST(event_params)
     WHERE key = 'ga_session_id') AS session_id,

    (SELECT value.string_value
     FROM UNNEST(event_params)
     WHERE key = 'page_location') AS page_location

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

prepared AS (
  SELECT
    *,
    CONCAT(user_pseudo_id, '-', CAST(session_id AS STRING)) AS user_session_id
  FROM base
  WHERE session_id IS NOT NULL
),

sessions_info AS (
  SELECT
    user_session_id,
    user_pseudo_id,
    session_id,

    COALESCE(
      REGEXP_EXTRACT(page_location, r'https?://[^/]+(/.*)'),
      REGEXP_EXTRACT(page_location, r'(/.*)')
    ) AS landing_page_location,

    country,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    traffic_source.name AS campaign,

    device.category AS device_category,
    device.language AS device_language,
    device.operating_system AS operating_system

  FROM prepared
  WHERE event_name = 'session_start'
),

events AS (
  SELECT
    user_session_id,
    user_pseudo_id,
    session_id,
    event_name,

    TIMESTAMP_MICROS(event_timestamp) AS event_time,
    DATE(TIMESTAMP_MICROS(event_timestamp)) AS event_date,

    CASE event_name
      WHEN 'session_start' THEN 1
      WHEN 'view_item' THEN 2
      WHEN 'add_to_cart' THEN 3
      WHEN 'begin_checkout' THEN 4
      WHEN 'add_shipping_info' THEN 5
      WHEN 'add_payment_info' THEN 6
      WHEN 'purchase' THEN 7
    END AS funnel_step

  FROM prepared

  WHERE event_name IN (
    'session_start',
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'add_shipping_info',
    'add_payment_info',
    'purchase'
  )
)

SELECT
  e.user_session_id,
  e.user_pseudo_id,
  e.session_id,
  
  e.event_time,
  e.event_date,
  e.event_name,
  e.funnel_step,



  s.landing_page_location,
  s.country,
  s.device_category,
  s.device_language,
  s.operating_system,
  s.source,
  s.medium,
  s.campaign

FROM events e
INNER JOIN sessions_info s
  USING (user_session_id)
