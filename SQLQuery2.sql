CREATE DATABASE EmployeeDetailsFile;

Use [EmployeeDetailsFile]

CREATE TABLE EDetails (

    EmployeeID int,
    EName varchar(50),
	Gender varchar(10),
	Age int,
	MobileNumber int,
	Address varchar(300),

    
);

SELECT * FROM EDetails;

INSERT INTO EDetails (EmployeeID, EName, Gender, Age, MobileNumber, Address)
VALUES ('12345','Nihaara','Female','15','1234567890','hdaiiloha');

INSERT INTO EDetails (EmployeeID, EName, Gender, Age, MobileNumber, Address)
VALUES ('12346','Yogi1','Male','16','978536252','nnmmxcldfjk');

INSERT INTO EDetails (EmployeeID, Ename,Gender,Age,MobileNumber,Address)
VALUES ('12347','Pavi','male','20','978536252','mmmcopopokjlm')


