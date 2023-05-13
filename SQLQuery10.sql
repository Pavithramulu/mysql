use _@test

select * from Sscore

select * from Sscore
SELECT Student_ID,[Name],(Tamil + English + Maths + Science + SScience) AS 'TOTAL' FROM Sscore
ORDER BY total DESC;

select * from Sscore
--select Student_ID,max(Tamil) from Sscore group by Student_ID;

SELECT [Name],max(Tamil) as 'HighestMark'
FROM Sscore  group by [Name];


select * from Sscore
SELECT Student_ID ,(Tamil) AS 'TOTAL' FROM Sscore
ORDER BY total DESC;

SELECT AVG(Tamil)
FROM Sscore as AverageScore;


select Student_ID,[name] from Sscore
union 
select mark,subject from A
