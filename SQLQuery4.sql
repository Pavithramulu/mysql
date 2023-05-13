use _@ABCD

select * from ytable

SELECT COUNT(Emp_id), City
FROM ytable
GROUP BY City
ORDER BY COUNT(Emp_id)  DESC;