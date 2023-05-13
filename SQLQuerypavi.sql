
USE [PAVI];

select * from worker

select GETDATE()


SELECT DISTINCT DEPARTMENT 
FROM worker;

SELECT LEN('DEPARTMENT');

SELECT FIRST_NAME, SALARY
FROM Worker
WHERE salary >= 50000 and salary <= 80000


SELECT * from 
Worker where JOINING_DATE = '2023-02-06 13:23:44'

select * from STATION


CREATE TABLE CITY(
ID int,
NAME char(20),
COUNTRYCODE varchar(5),
POPULATION int );

INSERT INTO CITY(ID,NAME,COUNTRYCODE,POPULATION)
VALUES('1662','America ','USA','210000');


CREATE TABLE STATION(
ID int,
CITYS char(20),
STATE varchar(5),
LAT_N int,
LONG_W int);

insert into STATION(CITYS)
values('Bengalar');

SELECT FIRST_NAME, SALARY
FROM Worker
WHERE salary >= 50000 and salary <= 80000

SELECT * FROM STATION
WHERE MOD(ID,2) = 0;

use test1

CREATE TABLE GTSTUDENT(

STNAME CHAR(30),
ID INT) ;

select * from  gtstudent

insert into GTSTUDENT (ID,STNAME)
VALUES(0010,'NIHA');

DROP TABLE GTSTUDENT
WHERE STNAME = 'NIHA';

DELETE FROM GTSTUDENT WHERE STNAME = 'NIHA';

select first_name,salary from Worker
where salary >=50000 and salary <= 10000

select getdate()

select len('last_name')


select * from collegestudent

select * from sdepartment


insert into collegestudent (StudentID,StudentName,Department,Percentage,DOJ)
VALUES(1001,'AAAA','MATHS',70,'2020-10-01 00:00:00.000');

SET IDENTITY_INSERT collegedepartment ON

INSERT INTO collegedepartment(department_ID,	department	,totalmark)
VALUES (14,'IT','764');

SET IDENTITY_INSERT collegedepartment OFF 

--inner join--

select * from collegestudent

select * from collegedepartment


SELECT STUDENTID s 
FROM collegestudent
INNER JOIN collegedepartment
ON collegestudent.DEPARTMENT = collegedepartment.DEPARTMENT;


--left join--

select * from collegestudent

select * from sdepartment


SELECT STUDENTID s 
FROM collegestudent
LEFT JOIN collegedepartment
ON collegestudent.DEPARTMENT = collegedepartment.DEPARTMENT;


--right join--
select * from collegestudent

select * from sdepartment


SELECT STUDENTID s 
FROM collegestudent
RIGHT JOIN collegedepartment
ON collegestudent.DEPARTMENT = collegedepartment.DEPARTMENT;

--full join--

select * from collegestudent

select * from collegedepartment


SELECT STUDENTID s 
FROM collegestudent
FULL OUTER JOIN collegedepartment
ON collegestudent.DEPARTMENT = collegedepartment.DEPARTMENT;


SELECT column_name s
FROM table1
INNER JOIN table2
ON table1.column_name = table2.column_name;

create database _@i

use _@i

select * from x
select * from y

SELECT empname,empid FROM x
UNION
SELECT emname,empid FROM y;


--alter table y
--add empid int

select A.empname,B.empdept
from x A
right join y B
on A.empid= B.empid;
 
 IF EXISTS(select top 1 empid from x where empid = 1235)
 BEGIN
	Select 'Exists'
 END
 ELSE
 BEGIN
	Select 'Not Exists'
 END



  ALTER TABLE 
 RENAME COLUMN mobnum to mobilenum;

 sp_rename 'x.mobnum', 'mobilenum', 'COLUMN';

 SELECT empid FROM x
UNION
SELECT mobilenum FROM y;

select * from x
select * from y


SELECT COUNT(empid), emname
FROM y
GROUP BY emname
ORDER BY COUNT(empid) ;

SELECT ALL empid
FROM y
WHERE emname = 'ffff'; 


select * from xtable
select * from ytable

create database _@ABCD

use _@ABCD


select * from xtable
select * from ytable
select * from AA

select A.Emp_name,A.Age,B.Mobile,B.City
from xtable A
full outer join ytable B
on A.Emp_id = b.Emp_id;




