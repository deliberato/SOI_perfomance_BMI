set search_path to eicu_crd;

with t1 as
(
select a.patientunitstayid,a.uniquepid,ROW_NUMBER() over (partition by a.uniquepid order by  a.hospitaladmityear ASC) AS position,a.hospitaladmityear, a.age, a. gender, a.ethnicity,a.hospitaladmitsource,a.unittype, a.unitadmitsource,a.apacheadmissiondx, a.admissionheight as height 
,a.admissionweight as weight, a.dischargeweight, b.readmit,c.apachescore, c.apacheversion, b.diedinhospital, c.predictedhospitalmortality
from patient a
left join apachepredvar b
on a.patientunitstayid = b.patientunitstayid
left join apachepatientresult c
on a.patientunitstayid = c.patientunitstayid
where a.age not in ( '0', '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15') -- excluding patients below 16 years
and a.admissionheight is not null
and a.admissionweight is not null
-- and a.dischargeweight is not null -- discharge weight has more NULL values than admission weight (90k vs 16k) so I decided to use admission weight.
and diedinhospital is not null
and b.readmit = 0 -- excluding readmission
and c.predictedhospitalmortality is not null
and c.predictedhospitalmortality != '-1'
and c.apacheversion = 'IV'
and  a.admissionweight between 30 and 320  -- excluding patients with weight < 30kg and more tha 320 kg -- I compared with dischargeweight and weigths outside this range didn´t make sense
and a.admissionheight between  120 and 230 -- excluding patients with height less than 120 cm and more than 220 cm

)
, t2 as
(
select t1.*, t1.weight/(t1.height*t1.height/10000) as bmi  -- creating bmi
from t1
)
, t3 as
(
select t2.*,
case
  when t2.bmi < 18.5 then 1
  when t2.bmi >= 18.5 and t2.bmi < 24.999999999 then 2
  when t2.bmi >= 25 and t2.bmi < 30 then 3
  when t2.bmi >= 30 then 4
  else 0 end as bmi_group -- creating BMI category
from t2
)
select *
from t3
where position =1 -- including just the first ICU admission (according to hospital admission year)
-- and bmi_group = 4 -- or 2 or 3 or 4



