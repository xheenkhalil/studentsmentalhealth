-- -----------DATA ANALYTICS PROJECT --------------
-- -----------Data source: https://www.kaggle.com/datasets/abdullahashfaqvirk/student-mental-health-survey

-- View the first few rows of the data
SELECT *
FROM dataset.mentalhealthsurvey
LIMIT 5;

-- Get Column names and datatypes
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'mentalhealthsurvey';

-- GET the Basic Statistics
SELECT
COUNT(*) AS total_records,
COUNT(DISTINCT university) AS unique_universities,
COUNT(DISTINCT degree_major) AS unique_degrees
FROM dataset.mentalhealthsurvey;

-- Check for missing VALUES
SELECT
	COUNT(*) - COUNT(gender) as missing_gender,
	COUNT(*) - COUNT(age) as miising_age,
	COUNT(*) - COUNT(university) as missing_university
	-- add as many columns as you like
FROM dataset.mentalhealthsurvey;

-- CREATE new table to find the avg cgpa and avg_sleep
ALTER TABLE dataset.mentalhealthsurvey
ADD COLUMN avg_cgpa DECIMAL(4, 2),
ADD COLUMN avg_sleep_hours DECIMAL(4, 2);

-- Split the columns and calculate the averages, then save them to the new columns
UPDATE dataset.mentalhealthsurvey
SET avg_cgpa = (
    (CAST(SUBSTRING_INDEX(cgpa, '-', 1) AS DECIMAL(4, 2)) + 
     CAST(SUBSTRING_INDEX(cgpa, '-', -1) AS DECIMAL(4, 2))) / 2
    ),
    avg_sleep_hours = (
    (CAST(SUBSTRING_INDEX(REPLACE(average_sleep, ' hrs', ''), '-', 1) AS DECIMAL(4, 2)) + 
     CAST(SUBSTRING_INDEX(REPLACE(average_sleep, ' hrs', ''), '-', -1) AS DECIMAL(4, 2))) / 2
    );

-- Create indexes to speed up up your analysis
CREATE INDEX idx_university ON mentalhealthsurvey(university(100));
CREATE INDEX idx_degree_major ON mentalhealthsurvey(degree_major(100));
CREATE INDEX Idx_avg_cgpa ON mentalhealthsurvey(avg_cgpa);

-- ANALYZE the data
ANALYZE TABLE dataset.mentalhealthsurvey;

-- CREATE A FUNCTION TO Categorize the stress level
DELIMITER //

CREATE FUNCTION get_stress_level(depression INT, anxiety INT, isolation INT)
RETURNS TEXT
DETERMINISTIC
BEGIN
    RETURN CASE
        WHEN (depression + anxiety + isolation) / 3.0 >= 4 THEN 'High'
        WHEN (depression + anxiety + isolation) / 3.0 >= 2 THEN 'Medium'
        ELSE 'Low'
    END;
END //

DELIMITER ;

-- USING the function to get the result from our data
SELECT get_stress_level(depression, anxiety, isolation) AS stress_level
FROM dataset.mentalhealthsurvey;

-- Create Column to store the result of stress level
ALTER TABLE dataset.mentalhealthsurvey
ADD COLUMN stress_level VARCHAR(50);

-- UPDATE THE columns with the results
UPDATE dataset.mentalhealthsurvey
SET stress_level = get_stress_level(depression, anxiety, isolation);

CREATE TEMPORARY TABLE temp_survey AS 
SELECT *,
	get_stress_level(depression, anxiety, isolation) as stress_levels,
    CAST(SUBSTRING(cgpa, 1, 3) as float) as numeric_cgpa
FROM mentalhealthsurvey;

-- ----------------QUESTION ANSWERED ---------------------------------

-- 1. Distribution of the student across different universities
-- count the students and find the pecentage in each universities
SELECT
    university,
    COUNT(*) AS count_students,
    COUNT(*) * 100.00 / (SELECT COUNT(*) FROM mentalhealthsurvey) AS percentage
FROM (
    SELECT *,
        get_stress_level(depression, anxiety, isolation) AS stress_levels,
        CAST(SUBSTRING(cgpa, 1, 3) AS FLOAT) AS numeric_cgpa
    FROM mentalhealthsurvey
) AS temp_survey
GROUP BY university
ORDER BY count_students DESC;

-- 2. Relationship between CGPA and DEPRESSION/ANXIETY
-- Calculate correlation coefficient
SELECT 
    (COUNT(*) * SUM(numeric_cgpa * depression) - SUM(numeric_cgpa) * SUM(depression)) / 
    (SQRT(COUNT(*) * SUM(numeric_cgpa * numeric_cgpa) - SUM(numeric_cgpa) * SUM(numeric_cgpa)) * 
     SQRT(COUNT(*) * SUM(depression * depression) - SUM(depression) * SUM(depression))) as cgpa_depression_correlation,
    
    (COUNT(*) * SUM(numeric_cgpa * anxiety) - SUM(numeric_cgpa) * SUM(anxiety)) / 
    (SQRT(COUNT(*) * SUM(numeric_cgpa * numeric_cgpa) - SUM(numeric_cgpa) * SUM(numeric_cgpa)) * 
     SQRT(COUNT(*) * SUM(anxiety * anxiety) - SUM(anxiety) * SUM(anxiety))) as cgpa_anxiety_correlation
FROM temp_survey;

-- 3. Academic pressure across degree majors:
-- Average academic pressure for each degree major
SELECT 
    degree_major,
    AVG(academic_pressure) as avg_academic_pressure
FROM temp_survey
GROUP BY degree_major
ORDER BY avg_academic_pressure DESC;

-- 4. Relationship between sports engagement and stress levels:
-- Average stress level for different sports engagement frequencies
SELECT 
    sports_engagement,
    AVG((depression + anxiety + isolation) / 3.0) as avg_stress_level
FROM temp_survey
GROUP BY sports_engagement
ORDER BY avg_stress_level DESC;

-- 5. Isolation levels for on-campus vs off-campus students:
-- Average isolation score for on-campus and off-campus students
SELECT 
    residential_status,
    AVG(isolation) as avg_isolation
FROM temp_survey
GROUP BY residential_status;

-- 6. Most common stress relief activity:
-- Step 1: Create a temporary table for activities
CREATE TEMPORARY TABLE temp_activities (
    activity VARCHAR(255)
);

-- Step 2: Insert split activities into the temporary table
INSERT INTO temp_activities (activity)
SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(stress_relief_activities, ',', numbers.n), ',', -1)) AS activity
FROM (
    SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 
    UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
) numbers
JOIN temp_survey ON CHAR_LENGTH(stress_relief_activities) - CHAR_LENGTH(REPLACE(stress_relief_activities, ',', '')) >= numbers.n - 1;

-- Step 3: Count the occurrences of each activity
SELECT 
    activity,
    COUNT(*) AS activity_count
FROM temp_activities
GROUP BY activity
ORDER BY activity_count DESC
LIMIT 5;

-- 7. Gender difference in future insecurity:
-- Average future insecurity score by gender
SELECT 
    gender,
    AVG(future_insecurity) as avg_future_insecurity
FROM temp_survey
GROUP BY gender;

-- 8. Relationship between sleep duration and CGPA:
-- Average CGPA for each sleep duration category
SELECT 
    average_sleep,
    AVG(numeric_cgpa) as avg_cgpa
FROM temp_survey
GROUP BY average_sleep
ORDER BY avg_cgpa DESC;

-- 9. Campus discrimination and mental health indicators:
-- Average mental health scores for students who experienced discrimination vs those who didn't
SELECT 
    campus_discrimination,
    AVG(depression) as avg_depression,
    AVG(anxiety) as avg_anxiety,
    AVG(isolation) as avg_isolation
FROM temp_survey
GROUP BY campus_discrimination;

-- 10. Academic workload for postgraduate vs undergraduate students:
-- Average academic workload for postgraduate and undergraduate students
SELECT 
    degree_level,
    AVG(academic_workload) as avg_academic_workload
FROM temp_survey
GROUP BY degree_level;

-- 11. Relationship between financial concerns and stress levels:
-- Correlation between financial concerns and average stress level
SELECT 
    (COUNT(*) * SUM(financial_concerns * ((depression + anxiety + isolation) / 3.0)) - SUM(financial_concerns) * SUM((depression + anxiety + isolation) / 3.0)) / 
    (SQRT(COUNT(*) * SUM(financial_concerns * financial_concerns) - SUM(financial_concerns) * SUM(financial_concerns)) * 
     SQRT(COUNT(*) * SUM(((depression + anxiety + isolation) / 3.0) * ((depression + anxiety + isolation) / 3.0)) - SUM((depression + anxiety + isolation) / 3.0) * SUM((depression + anxiety + isolation) / 3.0))) as financial_stress_correlation
FROM temp_survey;

-- 12. Study satisfaction across academic years:
-- Average study satisfaction for each academic year
SELECT 
    academic_year,
    AVG(study_satisfaction) as avg_study_satisfaction
FROM temp_survey
GROUP BY academic_year
ORDER BY academic_year;

-- 13. Correlation between social relationships and isolation scores:
-- Calculate correlation coefficient
SELECT 
    (COUNT(*) * SUM(social_relationships * isolation) - SUM(social_relationships) * SUM(isolation)) / 
    (SQRT(COUNT(*) * SUM(social_relationships * social_relationships) - SUM(social_relationships) * SUM(social_relationships)) * 
     SQRT(COUNT(*) * SUM(isolation * isolation) - SUM(isolation) * SUM(isolation))) as social_isolation_correlation
FROM temp_survey;

-- 14. Stress relief activities for students with high academic pressure:
-- Most common stress relief activities for students with high academic pressure
-- Step 1: Create a temporary table for activities
CREATE TEMPORARY TABLE temp_activities (
    activity VARCHAR(255)
);

-- Step 2: Insert split activities for high pressure students into the temporary table
INSERT INTO temp_activities (activity)
SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(stress_relief_activities, ',', numbers.n), ',', -1)) AS activity
FROM (
    SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 
    UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
) numbers
JOIN temp_survey ON CHAR_LENGTH(stress_relief_activities) - CHAR_LENGTH(REPLACE(stress_relief_activities, ',', '')) >= numbers.n - 1
WHERE academic_pressure > 4;

-- Step 3: Count the occurrences of each activity
SELECT 
    activity,
    COUNT(*) AS activity_count
FROM temp_activities
GROUP BY activity
ORDER BY activity_count DESC
LIMIT 5;

-- 15. Distribution of mental health indicators across universities:
-- Average depression, anxiety, and isolation scores for each university
SELECT 
    university,
    AVG(depression) as avg_depression,
    AVG(anxiety) as avg_anxiety,
    AVG(isolation) as avg_isolation
FROM temp_survey
GROUP BY university
ORDER BY (avg_depression + avg_anxiety + avg_isolation) / 3 DESC;

-- ------------- Scripts writen by THOMAS MOSES -----
-- ------------- Data Analyst/Scientist -------------






    
