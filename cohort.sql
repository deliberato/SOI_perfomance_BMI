set search_path to eicu_crd;

with t1 as
(
select a.patientunitstayid, a.age, a.admissionheight as height ,a.admissionweight, a.dischargeweight  , b.readmit, c.apacheversion, b.diedinhospital, c.predictedhospitalmortality
from patient a
left join apachepredvar b
on a.patientunitstayid = b.patientunitstayid
left join apachepatientresult c
on a.patientunitstayid = c.patientunitstayid
where a.age not in ( '0', '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15')
and a.admissionheight is not null
and a.admissionweight is not null
and a.dischargeweight is not null
and diedinhospital is not null
and b.readmit = 0
and c.predictedhospitalmortality is not null
and c.predictedhospitalmortality != '-1'
and c.apacheversion = 'IV'
and a.admissionheight != 0.00
)
, t2 as
(
select t1.patientunitstayid,t1.age, t1.admissionweight, t1.dischargeweight,t1.diedinhospital, t1.predictedhospitalmortality,
case when t1.height < 50 then t1.height*100 -- correcting some heigths from m to cm
     when t1.height > 1000 then t1.height/100 -- correcting height
     else t1.height end as height
from t1
) 
,t3 as
(
select t2.*, t2.admissionweight/(t2.height*t2.height/10000) as bmi  -- admissionweight seems more trustful, take a look
from t2
)
, t4 as
(
select t3.*,
case
  when t3.bmi < 18.5 then 1
  when t3.bmi >= 18.5 and t3.bmi < 24.999999999 then 2
  when t3.bmi >= 25 and t3.bmi < 30 then 3
  when t3.bmi >= 30 then 4
  else 0 end as bmi_group
from t3
)
select *
from t4
where bmi_group = 1 -- or 2 or 3 or 4
