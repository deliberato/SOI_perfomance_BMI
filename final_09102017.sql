set search_path to eicu_crd,public;

with t1 as
(
select a.patientunitstayid,a.uniquepid,ROW_NUMBER() over (partition by a.uniquepid order by  a.hospitaladmityear ASC) AS position,a.hospitaladmityear, a.age
,case -- fixing age >89 to 93
      when a.age like '%89%' then '93' 
      else a.age end as age_fixed
, a. gender, a.ethnicity,a.hospitaladmitsource,a.unittype, a.unitadmitsource,a.apacheadmissiondx,d.diagnosisstring, a.admissionheight as height ,a.admissionweight as weight, a.dischargeweight
, b.readmit,a.hospitalid,h.numbedscategory, h.teachingstatus, h.region,  b.aids, b.hepaticfailure, b.lymphoma, b.metastaticcancer,b.leukemia, b.immunosuppression, b. diabetes, b.cirrhosis, b.electivesurgery
,t.dialysis as chronic_dialysis_prior_to_hospital,ch.charlson_score,c.unabridgedunitlos as real_icu_los,c. actualiculos,c.unabridgedhosplos as real_hospital_los,c.actualhospitallos, c.unabridgedactualventdays as ventduration,t.intubated as intubated_first_24h
,(cv.sofa_cv+respi.sofa_respi+ renal.sofarenal+others.sofacoag+ others.sofaliver+others.sofacns) as sofatotal, c.predictedicumortality, c.actualicumortality
,case -- fixing icu mortality
      when lower(c.actualicumortality) like '%alive%' THEN 0
      when lower(c.actualicumortality) like '%expired%' THEN 1 
      else null end as died_icu
,c.apachescore,c.apacheversion,c.predictedhospitalmortality,c.actualhospitalmortality,b.diedinhospital
from patient a
left join apachepredvar b
on a.patientunitstayid = b.patientunitstayid
left join apachepatientresult c
on a.patientunitstayid = c.patientunitstayid
left join apacheapsvar t
on a.patientunitstayid = t.patientunitstayid
left join sofacv cv
on a.patientunitstayid = cv.patientunitstayid
left join sofarespi respi
on a.patientunitstayid = respi.patientunitstayid
left join sofarenal renal
on a.patientunitstayid = renal.patientunitstayid
left join sofa3others others
on a.patientunitstayid = others.patientunitstayid
left join charlson_score ch
on a.patientunitstayid = ch.patientunitstayid
left join diagnosis d
on a.patientunitstayid = d.patientunitstayid
left join hospital h
on  a.hospitalid = h.hospitalid
where a.age not in ( '0', '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15') -- excluding patients below 16 years
and a.admissionheight is not null
and a.admissionweight is not null
-- and a.dischargeweight is not null -- discharge weight has more NULL values than admission weight (90k vs 16k) so I decided to use admission weight.
and diedinhospital is not null
and b.readmit = 0 -- excluding readmission
and c.predictedhospitalmortality != '-1'
and c.apacheversion = 'IV'
and  a.admissionweight between 30 and 320  -- excluding patients with weight < 30kg and more tha 320 kg -- I compared with dischargeweight and weigths outside this range didn´t make sense
and a.admissionheight between  120 and 230 -- excluding patients with height less than 120 cm and more than 220 cm
and lower(d.diagnosisstring) not like 'pregnancy'-- excluding patients with preganacy related diagnosis
)
, t2 as  -- creating bmi
(
select t1.*, t1.weight/(t1.height*t1.height/10000) as bmi 
from t1
)
, t3 as -- creating BMI category
(
select t2.*,
case
  when t2.bmi < 18.5 then 1
  when t2.bmi >= 18.5 and t2.bmi < 24.999999999 then 2
  when t2.bmi >= 25 and t2.bmi < 30 then 3
  when t2.bmi >= 30 then 4
  else 0 end as bmi_group 
from t2
)
select t3.*,
case
	when t3.bmi_group = 1 then 'underweight'
	when t3.bmi_group = 2 then 'normal weight'
	when t3.bmi_group = 3 then 'overweight'
	when t3.bmi_group = 4 then 'obese'
	else null end as bmi_category 
from t3
where position =1 -- including just the first ICU admission (according to hospital admission year)
-- and bmi_group = 4 -- or 2 or 3 or 4 -- to din the number of patients of each BMI category
