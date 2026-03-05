# SQL Stored Procedures

This document lists the **signatures** of the stored procedures available in this folder.

All parameters follow the convention:

- `p_` prefix for procedure parameters
- `NULL` means **no filter**
- `p_min_valid_default` is the default threshold for valid hourly samples

---

# Procedures

## sp_active_accounts

```sql
CALL sp_active_accounts();
```

---

## sp_sleep_tidy

```sql
CALL sp_sleep_tidy(
  p_date_from,
  p_date_to,
  p_userId,
  p_deviceId,
  p_firmware
);
```

Example

```sql
CALL sp_sleep_tidy(NULL, NULL, NULL, NULL, NULL);
```

---

## sp_gps_daily

```sql
CALL sp_gps_daily(
  p_min_valid_default,
  p_date_from,
  p_date_to,
  p_userId,
  p_deviceId,
  p_min_valid_longitude,
  p_min_valid_latitude,
  p_min_valid_accuracy
);
```

---

## sp_myair_daily

```sql
CALL sp_myair_daily(
  p_min_valid_default,
  p_date_from,
  p_date_to,
  p_userId,
  p_deviceId,
  p_min_valid_pm1,
  p_min_valid_pm25,
  p_min_valid_pm10,
  p_min_valid_pc03,
  p_min_valid_pc05,
  p_min_valid_pc1,
  p_min_valid_pc25,
  p_min_valid_pc5,
  p_min_valid_pc10,
  p_min_valid_temperature,
  p_min_valid_humidity,
  p_min_valid_pressure,
  p_min_valid_sound,
  p_min_valid_uvb,
  p_min_valid_light
);
```

---

## sp_smartwatchhigh_daily

```sql
CALL sp_smartwatchhigh_daily(
  p_min_valid_default,
  p_date_from,
  p_date_to,
  p_userId,
  p_deviceId,
  p_min_valid_heartrate,
  p_min_valid_oxygens,
  p_min_valid_breathrate,
  p_min_valid_sleeprate
);
```

---

## sp_smartwatchlow_daily

```sql
CALL sp_smartwatchlow_daily(
  p_min_valid_default,
  p_date_from,
  p_date_to,
  p_userId,
  p_deviceId,
  p_min_valid_steps,
  p_min_valid_cal,
  p_min_valid_bphigh,
  p_min_valid_bplow,
  p_min_valid_bodytemp,
  p_min_valid_skintemp
);
```
