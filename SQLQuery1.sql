use _@ABCD

create table B(
Employee_ID int,
Employee_Name varchar(50),
Designation varchar(50),
Age int,
City varchar(50))

select * from B

insert into B(Employee_ID,Employee_Name,Designation,Age,City)
values(1005,'Dineshkumar','Executive','28','Chennai')

update B
set Employee_Name = 'Vikashni'
where Employee_ID = 1003;

select * from B
select sum(Age) 
from B
