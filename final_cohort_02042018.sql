-- ---------------------------------------------------------------------------------------
-- Title: SQL Code extraction
-- Description:  Please read "read me" for details about inclusion and exclusion criteria 
-- SET search_path to eicu_crd,public;
-- 108402 patietunitstyid
-- ---------------------------------------------------------------------------------------

WITH diag as
(
select patientunitstayid
 , max(case when lower(diagnosisstring) like '%pregnancy%' then 1 else 0 end) as pregnant
from diagnosis 
group by patientunitstayid
)
,t1 as -- extracting most of the variables
(
SELECT 
	 a.patientunitstayid
	, a.uniquepid, ROW_NUMBER() OVER (partition BY a.uniquepid ORDER BY  a.hospitaladmityear, a.hospitaladmitoffset DESC) AS position
	, a.hospitaladmityear
	, a.age
        , CASE -- fixing age >89 to 93
                WHEN a.age LIKE '%89%' then '93' 
                ELSE a.age 
          END AS age_fixed
    , a.gender
	, a.ethnicity
	, a.hospitaladmitsource
	, a.unittype
	, a.unitadmitsource
	, a.apacheadmissiondx
	, d.pregnant
	, a.admissionheight as height
	, a.admissionweight as weight
	, a.dischargeweight
    , b.readmit
	, a.hospitalid
	, h.numbedscategory
	, h.teachingstatus
	, h.region
	, b.aids
	, b.hepaticfailure
	, b.lymphoma
	, b.metastaticcancer
	, b.leukemia
	, b.immunosuppression
	, b.diabetes
	, b.cirrhosis
	, b.electivesurgery
  , t.dialysis as chronic_dialysis_prior_to_hospital
	, c.unabridgedunitlos as real_icu_los
	, c.actualiculos
	, c.unabridgedhosplos as real_hospital_los
	, c.actualhospitallos
  , c.unabridgedactualventdays as ventduration
	, t.intubated as intubated_first_24h
  , c.predictedicumortality
	, c.actualicumortality
	, c.acutephysiologyscore
  , CASE -- fixing icu mortality
      	WHEN lower(c.actualicumortality) LIKE '%alive%' THEN 0
      	WHEN lower(c.actualicumortality) LIKE '%expired%' THEN 1 
      	ELSE NULL 
      END AS died_icu
  , ch.charlson_score
	, ch.mets6
	, ch.aids6
	, ch.liver3
	, ch.stroke2
	, ch.renal2
	, ch.dm
	, ch.cancer2
	, ch.leukemia2
	, ch.lymphoma2
	, ch.mi1
	, ch.chf1
	, ch.pvd1
	, ch.tia1
  , ch.dementia1
	, ch.copd1
	, ch.ctd1
	, ch.pud1
	, ch.liver1
	, ch.age_score
  , (cv.sofa_cv+respi.sofa_respi+ renal.sofarenal+others.sofacoag+ others.sofaliver+others.sofacns) as sofatotal
  , c.apachescore
  , c.apacheversion
  , c.predictedhospitalmortality
  , o.oasis
  , o.oasis_prob
  , b.diedinhospital
FROM patient a
LEFT JOIN apache_pred_var b
     ON a.patientunitstayid = b.patientunitstayid
LEFT JOIN apache_pacient_result c
     ON a.patientunitstayid = c.patientunitstayid
     AND c.apacheversion = 'IV'
LEFT JOIN apache_aps_var t
     ON a.patientunitstayid = t.patientunitstayid
LEFT JOIN diag d
     ON a.patientunitstayid = d.patientunitstayid
LEFT JOIN hospital h
     ON a.hospitalid = h.hospitalid
LEFT JOIN sofacv cv
     ON a.patientunitstayid = cv.patientunitstayid
LEFT JOIN sofarespi respi
     ON a.patientunitstayid = respi.patientunitstayid
LEFT JOIN sofarenal renal
     ON a.patientunitstayid = renal.patientunitstayid
LEFT JOIN sofa3others others
     ON a.patientunitstayid = others.patientunitstayid
LEFT JOIN charlson_score ch
     ON a.patientunitstayid = ch.patientunitstayid
LEFT JOIN oasis o
     ON a.patientunitstayid = o.patientunitstayid
 WHERE 
 a.age NOT in ( '0', '1','2','3','4','5','6','7','8','9','10','11','12','13','14','15') -- excluding patients below 16 years
AND a.admissionheight IS NOT null
AND a.admissionweight IS NOT  null
AND c.predictedhospitalmortality != -1
AND a.admissionweight != 0.00   --  BETWEEN 30 AND  320  -- excluding patients with weight < 30kg and more tha 320 kg -- I compared with dischargeweight and weigths outside this range didn´t make sense
AND a.admissionheight != 0.00  --  BETWEEN  120 AND  230 -- excluding patients with height less than 120 cm and more than 220 cm
AND d.pregnant != 1 -- excluding patients with preganacy related diagnosis
)
 , t2 AS  -- creating body mass index variable
 (
 SELECT t1.*, t1.weight/(t1.height*t1.height/10000) AS bmi 
 FROM t1
 )
 , t3 AS -- creating BMI category
(
 SELECT t2.*,
CASE
  WHEN t2.bmi < 18.5 THEN 1 -- underweight
  WHEN t2.bmi >= 18.5 AND t2.bmi < 24.999999999 then 2 -- normal weight
  WHEN t2.bmi >= 25 AND t2.bmi < 29.999999999 then 3 -- overweight
  WHEN t2.bmi >= 30 AND t2.bmi < 39.999999999 THEN 4 -- obese
  WHEN t2.bmi >= 40 THEN 5 
  ELSE 0 
 END AS bmi_group 
 FROM t2
WHERE t2.bmi between 10 and 65
)
SELECT count(patientunitstayid)
FROM  t3
where  t3.position = 1 -- including just the first ICU admission (according to hospital admission year)
