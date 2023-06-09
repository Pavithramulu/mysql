USE [JKS_03_01_2023]
GO
/****** Object:  StoredProcedure [dbo].[CalibarationSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CalibarationSP]
							   (
							   @Action varchar(75)=null,
							   @CalibarationId int =0,
							   @CalibarationNo varchar(20)=null,
							   @CalibarationDate varchar(20)=null,
							   @NextCalibarationDate varchar(20)=null,
							   @MachineId int =0,
							   @RecordNo varchar(50)=null,
							   @RecordDate varchar(20)=null,
							   @TestCertificateNo varchar(50)=null,
							   @CalibarationBy varchar(100)=null,
							   @Result varchar(20)=null,
							   @Reason varchar(100)=null,
							   @ApprovedBy int =0,
							   @CreatedBy int =0,
							   @Attachment varchar(max)=null,
							   @CalibarationSub CalibarationSub readonly,
							   @MachineStatus VARCHAR(20)=NULL,
							   @Status VARCHAR(20)=NULL

							   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertCalibarationHistory'
BEGIN
   IF @CalibarationId=0
   BEGIN
      SET @CalibarationId= ISNULL((select top 1 calibarationid +1 from CalibarationHistory   order by calibarationid desc ),1);
	  SET @CalibarationNo=@CalibarationId;
   END
   ELSE
   BEGIN
      UPDATE CalibarationHistory SET isActive=0 WHERE CalibarationId=@CalibarationId;
      UPDATE CalibarationSub SET isActive=0 WHERE CalibarationId=@CalibarationId;
   END
     INSERT INTO [dbo].[CalibarationHistory]
							   (
							    [CalibarationId]
							   ,[CalibarationNo]
							   ,[CalibarationDate]
							   ,[NextCalibarationDate]
							   ,[MachineId]
							   ,[RecordNo]
							   ,[RecordDate]
							   ,[TestCertificateNo]
							   ,[CalibarationBy]
							   ,[Result]
							   ,[Reason]
							   ,[ApprovedBy]
							   ,[Attachment]
							   ,[CreatedBy]
							   )
					VALUES
						    (
							    @CalibarationId
							   ,@CalibarationNo
							   ,@CalibarationDate
							   ,@NextCalibarationDate
							   ,@MachineId
							   ,@RecordNo
							   ,@RecordDate
							   ,@TestCertificateNo
							   ,@CalibarationBy
							   ,@Result
							   ,@Reason
							   ,@ApprovedBy
							   ,@Attachment
							   ,@CreatedBy
							) 
			INSERT INTO CalibarationSub
										(
										CalibarationId,
										Observation,
										Remarks,
										CreatedBy
										)
								SELECT @CalibarationId,
								        Observation,
										Remarks,
										@CreatedBy from @CalibarationSub;
			UPDATE CalibarationHistory SET RecordNo=@RecordNo WHERE MachineId=@MachineId;
			UPDATE MachineDetails SET HistoryCardNo=@RecordNo, LastCalibrationDate=@CalibarationDate , 
			                          NextCalibrationDate=@NextCalibarationDate 
								  WHERE MachineId=@MachineId;
			SELECT '1'
END
ELSE IF @Action='GetCalibarationRemainderCount'
BEGIN
      SELECT COUNT(M.MachineId) as CalibrationRemainder FROM MachineDetails M
	  where M.IsActive=1 and M.IsNotInUse=0 
	  and M.NextCalibrationDate<>'' and M.NextCalibrationDate is not null  and cast(M.NextCalibrationDate as date) <= DATEADD(DAY, 10 , cast(getDate() as date))
END
ELSE IF @Action='GetCalibarationRemainderDtls'
BEGIN
     SELECT M.MachineId, M.MachineCode, M.MachineName, M.LastCalibrationDate, M.NextCalibrationDate FROM MachineDetails M
	 where M.IsActive=1  and M.IsNotInUse=0 
	 and M.NextCalibrationDate<>'' and M.NextCalibrationDate is not null  and cast(M.NextCalibrationDate as date) <= DATEADD(DAY, 10 , cast(getDate() as date))
END
ELSE IF @Action='GetCalibarationDtls'
BEGIN
	Select * from (
			Select C.CalibarationId, C.RecordNo , C.RecordDate,M.MachineCode, M.MachineName, C.TestCertificateNo , E.EmpName  as ApprovedBy,  
			C.CalibarationDate, C.NextCalibarationDate,C.Attachment,
			(MAX(C.CalibarationId) OVER (PARTITION BY C.MachineId)) AS MCalibarationId from CalibarationHistory C 
			inner join MachineDetails M on M.MachineId=C.MachineId and M.IsActive=1 and M.Status='Active'
			inner join EmployeeDetails E on E.EmpId=C.ApprovedBy and E.IsActive=1 
			where C.IsActive=1 and C.Result='Approve'
	 )A where A.CalibarationId=A.MCalibarationId 
	 order by A.CalibarationId desc
END
ELSE IF @Action='GetCalibarationDtlsByMachineId'
BEGIN
    SELECT C.CalibarationId, C.RecordNo,C.RecordDate, C.CalibarationDate,C.NextCalibarationDate, C.Result FROM CalibarationHistory C
	WHERE C.IsActive=1 AND C.MachineId=@MachineId 
	order by C.CalibarationId desc;
END

ELSE IF @Action='GetCalibarationDtlsById'
BEGIN
	SELECT CalibarationId,CalibarationNo,C.CalibarationDate, C.NextCalibarationDate, C.MachineId, C.RecordNo, C.RecordDate, 
	C.TestCertificateNo, C.CalibarationBy, C.Result, C.Reason, C.Attachment, C.ApprovedBy, M.Type, M.CalibrationFrequency, 
	C.Attachment
	FROM CalibarationHistory C
	inner join MachineDetails M on M.MachineId=C.MachineId and M.IsActive=1 
	WHERE C.IsActive=1 AND C.CalibarationId = @CalibarationId

    Select CS.Observation, CS.Remarks from CalibarationSub CS
	where CS.IsActive=1 and CS.CalibarationId=@CalibarationId;
END
ELSE IF @Action ='GetRejectedCalibarartionDtls'
BEGIN
            Select C.CalibarationId, C.RecordNo , C.RecordDate,M.MachineCode, M.MachineName, C.TestCertificateNo , E.EmpName  as ApprovedBy,  
			C.CalibarationDate, C.NextCalibarationDate,C.Attachment,
			(MAX(C.CalibarationId) OVER (PARTITION BY C.MachineId)) AS MCalibarationId from CalibarationHistory C 
			inner join MachineDetails M on M.MachineId=C.MachineId and M.IsActive=1 
			inner join EmployeeDetails E on E.EmpId=C.ApprovedBy and E.IsActive=1 
			where C.IsActive=1 AND C.Result='Reject' ORDER BY C.CalibarationId DESC
END
ELSE IF @Action='GetCalibarationPrintDtls'
BEGIN  
	Select M.MachineCode,M.MachineName,M.CalibrationFrequency,M.Make,M.LeastCount,M.Range,
	M.SerialNo,M.DateOfIncorparation,M.ErrorLimit,M.Location
	From MachineDetails M WHERE IsActive =1 AND M.MachineId= @MachineId

   Select * into #Temp from(Select CalibarationId from CalibarationHistory where MachineId=@MachineId)A;
   Select C.CalibarationId, C.CalibarationDate,C.NextCalibarationDate,C.CalibarationBy,C.Reason,C.TestCertificateNo from CalibarationHistory C
   where C.IsActive=1  and C.MachineId=@MachineId;

   Select CalibarationId,Observation,Remarks from CalibarationSub where IsActive=1 and  CalibarationId in (Select CalibarationId from #Temp)
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[CommonSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[CommonSP]
                         (
						 @Action varchar(75)=null,
						 @Type varchar(20)=null,
						 @TypeId int =0,
						 @Status varchar(20 )=null,
						 @PoType VARCHAR(20)=NULL,
						 @PrePOId INT =0,
						 @WorkPlace varchar(20)=null,
						 @ItemId int =0,
						 @RawMaterialId int =0,
						 @VendorId int =0,
						 @CountryId INT =0,
						 @StateId INT =0
						 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
If @Action='GetCustomerDtlsByType' 
BEGIN
   SELECT CustomerId, CustomerName , CustomerType  from CustomerMaster where IsActive=1 and (@Type is null or CustomerType=@Type)
END
ELSE IF @Action='GetItemDtlsByType'
BEGIN
    SELECT I.ItemId ,I.ItemTypeId as TypeId, I.PartNo + '-' + I.Description as ItemName,I.Price, U.UnitName  FROM ItemMaster I 
	inner join UnitMaster U on U.UnitId=I.UOMId and U.IsActive=1 
	 WHERE I.IsActive=1 AND @TypeId in (0, I.ItemTypeId);
END
ELSE IF @ACTION='GetRawMaterial'
BEGIN
    SELECT RawMaterialId ,CodeNo, Description , Shape, MaterialId , Text1, Text2, Text3,
	
	Value1 , Value2 , Dimension,
	 Value3 FROM RawMaterial RM
	  WHERE IsActive=1 
END
ELSE IF @Action='GetMaterial'
BEGIN
     SElect materialId, materialCode, materialName from MaterialMaster where isActive=1 order by materialId asc
END
ELSE IF @Action = 'GetRMFormula'
BEGIN
		Select MaterialId,Shape, Text from RMFormula 
END
ELSE IF @Action='GetMachineDtlsByType'
BEGIN
   SELECT MachineId, MachineCode +' - ' + MachineName as MachineCode_Name, HistoryCardNo, CalibrationFrequency  FROM MachineDetails WHERE IsActive=1 AND 
   (@Type is null or Type=@Type) and (@Status is null or Status=@Status)
END
ELSE IF @Action='GetItemType'
BEGIN
    SELECT ItemTypeId, ItemTypeName FROM ItemTypeMaster WHERE IsActive=1 
END
ELSE IF @Action='GetEmployeeDtls'
BEGIN
    SELECT EmpId, EmpName  +'(' + EmpCode+')' AS EmpCode_Name FROM EmployeeDetails WHERE IsActive=1 
END
ELSE IF @Action='GetAllPONos'
BEGIN
		IF @PoType='CustomerPO'
		BEGIN
			 Select PM.PrePOId,PM.PrePONo from PrePOMain PM
			 where PM.IsActive=1 
		END
		ELSE 
		BEGIN
		    SELECT JM.JobOrderPOId as PrePOId,JM.PONo as PrePONo  FROM JobOrderPOMain JM
			WHERE JM.IsActive=1 
		END
END
ELSE IF @Action='GetAllItemDtlsByPrePOId'
BEGIN
    IF @PoType='CustomerPO'
	BEGIN
			SELECT  PS.ItemId, I.PartNo +'-' + I.Description as PartNo_Description, isnull(R.RawMaterialId,0) as RawMaterialId,R.Description as RawMaterialName,
			 PS.Qty as POQty,
			RP.Weight  FROM PrePOSub PS
			left  join RMPlanning RP on RP.PrePOId=PS.PrePOId and RP.ItemId=PS.ItemId and RP.IsActive=1
			left join RawMaterial R on R.RawMaterialId=RP.RawMaterialId and R.IsActive=1 
			inner join ItemMaster I on I.ItemId=PS.ItemId and I.IsActive=1
			where PS.IsActive=1 and PS.PrePOId=@PrePOId;
	END
	ELSE
	BEGIN
	       SELECT JS.JobOrderPOSubId as ItemId, JS.PartNo +'-' + JS.ItemName as PartNo_Description,JS.JobOrderPOSubId as RawMaterialId, JS.ItemName as RawMaterialName, JS.Qty as POQty ,
		   '0' as Weight  FROM JobOrderPOSub JS
		   where JS.IsActive=1 and JS.JobOrderPOId=@PrePOId
	END
END
ELSE IF @Action='GetRouteCardOperationsDtls'
BEGIN
    IF @PoType='CustomerPO'
	 BEGIN
		 SELECT RC.RouteEntryId, RC.RoutLineNo, RC.OperationId,'P'+cast(RC.RoutLineNo as varchar)+ ' - ' +O.OperationName as Operation, RC.ProcessQty,  ISNULL(PO.AccQty,'0') AS AvlQty FROM RouteCardEntry RC
		  LEFT JOIN POProcessQtyDetails PO ON PO.POType=@PoType AND PO.RouteEntryId=RC.RouteEntryId AND PO.RoutLineNo=RC.RoutLineNo-1 AND PO.IsActive=1 
		 inner join OperationMaster O on O.OperationId=RC.OperationId and O.IsActive=1 
		 where RC.IsActive=1 and RC.PrePOId=@PrePOId and RC.ItemId =@ItemId and RC.POType=@PoType and RC.WorkPlace like '%'+@WorkPlace+'%' 
   
   END
	ELSE
	BEGIN
	     SELECT RC.RouteEntryId, RC.RoutLineNo,RC.OperationId,'P'+cast(RC.RoutLineNo as varchar)+ ' - ' +O.OperationName as Operation,RC.ProcessQty,
		 ISNULL(PO.AccQty,'0') AS AvlQty 
		 FROM RouteCardEntry RC
		 inner join JobOrderPOSub J on J.JobOrderPOId=RC.PrePOId and J.JobOrderPOSubId=RC.ItemId and J.IsActive=1 
		 inner join OperationMaster O on O.OperationId=RC.OperationId and O.IsActive=1 
		 LEFT JOIN POProcessQtyDetails PO ON PO.POType=@PoType AND PO.RouteEntryId=RC.RouteEntryId AND PO.RoutLineNo=RC.RoutLineNo-1 AND PO.IsActive=1 
		 where RC.IsActive=1 AND RC.RoutLineNo<>1 and RC.PrePOId=@PrePOId and RC.ItemId =@ItemId and RC.POType=@PoType
		 and RC.WorkPlace like '%'+@WorkPlace+'%'
	
	END
END
ELSE IF @Action='GetDimensionDtlsByRMId'
BEGIN
   Select RD.RMDimensionId,Text1 +'-' + Value1 + case when Text2 <>'' and  Text2 is not  null then ' * ' + Text2+ '-'+Value2 +' * ' else ' * ' end +Text3 +'-' +Value3 as Dimension, RD.UnitWeight,RD.QtyNos from RMDimensionWiseStock RD
   where RD.IsActive=1 AND RD.RawMaterialId=@RawMaterialId and RD.VendorId=@VendorId;
END
ELSE IF @Action='GetCurrency'
BEGIN
   SELECT Code from CURRENCY WHERE IsActive=1 
END
IF @Action='GetCountryDetails'
BEGIN
     SELECT id,Name+'('+CountryCode+')' as countryCode_Name,CountryCode FROM CountryMaster
END
ELSE IF @Action='GetStateDetails'
BEGIN
    SELECT * FROM STATEMASTER where (@CountryId=0 or  CountryID=@CountryId);
END
ELSE IF @Action='GetCityDetails'
BEGIN
   SELECT * FROM CityMaster where (@StateId =0 or StateId=@StateId);
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[CompanySP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CompanySP]
						(
						@Action varchar(75)=null,
						@CompanyMasterId int =0,
						@Name varchar(75)=null,
						@Address varchar(max)=null,
						@PhoneNo varchar(50)=null,
						@GSTIN varchar(50)=null,
						@PANNo varchar(50)=null,
						@TINNo varchar(50)=null,
						@CST varchar(50)=null,
						@StartFrom varchar(50)=null,
						@Logo varchar(50)=null,
						@Email varchar(75)=null,
						@CountryId int =0,
						@CityId int =0,
						@StateId int =0,
						@Pincode varchar(50)=null,
						@Website varchar(75)=null,
						@Telephone1 varchar(50)=null,
						@Telephone2 varchar(50)=null,
						@CINNo varchar(50)=null,
						@AccountNo varchar(50)=null,
						@IFSCCode varchar(50)=null,
						@SwiftCode varchar(50)=null,
						@ADCode varchar(50)=null,
						@BankAddress varchar(500)=null,
						@CreatedBy int =0
						)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertCompany'
BEGIN
    IF @CompanyMasterId=0
	BEGIN
	   SET @CompanyMasterId=ISNULL((SELECT TOP 1 CompanyMasterId+1 FROM CompanyMaster ORDER BY CompanyMasterId DESC),1);
	END
	ELSE
	BEGIN
	   UPDATE CompanyMaster SET IsActive=0 WHERE CompanyMasterId=@CompanyMasterId;
	END
	INSERT INTO [dbo].[CompanyMaster]
					   (
					    [CompanyMasterId]
					   ,[Name]
					   ,[Address]
					   ,[PhoneNo]
					   ,[GSTIN]
					   ,[PANNo]
					   ,[TINNo]
					   ,[CST]
					   ,[StartFrom]
					   ,[Logo]
					   ,[Email]
					   ,[CountryId]
					   ,[CityId]
					   ,[StateId]
					   ,[PinCode]
					   ,[Website]
					   ,[Telephone1]
					   ,[Telephone2]
					   ,[CINNo]
					   ,[AccountNo]
					   ,[IFSCCode]
					   ,[SwiftCode]
					   ,[adCode]
					   ,[BankAddress]
					   ,[CreatedBy]
					   )
		    VALUES
			          (
					   @CompanyMasterId,
					   @Name,
					   @Address,
					   @PhoneNo,
					   @GSTIN,
					   @PANNo,
					   @TINNo,
					   @CST,
					   @StartFrom,
					   @Logo,
					   @Email,
					   @CountryId,
					   @CityId,
					   @StateId,
					   @PinCode,
					   @Website,
					   @Telephone1,
					   @Telephone2,
					   @CINNo,
					   @AccountNo,
					   @IFSCCode,
					   @SwiftCode,
					   @adCode,
					   @BankAddress,
					   @CreatedBy
					   )
		SELECT '1'
END
ELSE IF @Action='GetCompanyDtls'
BEGIN
    Select C.Name,C.Address,C.PhoneNo,c.GSTIN,C.PANNo,C.TINNo,C.CST,C.StartFrom,C.Logo,C.Email,
	C.CountryId,C.CityId,C.StateId,C.Pincode,C.Website,C.Telephone1, C.Telephone2,C.CINNo,C.AccountNo,C.IFSCCode,C.SwiftCode,
	C.adCode,C.BankAddress
	 from CompanyMaster C
	where C.IsActive=1 
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH


GO
/****** Object:  StoredProcedure [dbo].[CustomerPOSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CustomerPOSP]
                                     (
									 @Action varchar(75)=null,
									 @CustomerPOId int =0,
									 @PONo varchar(20)=null,
									 @Date varchar(20)=null,
									 @PrePOId int =0,
									 @CreatedBy int =0,									 
								   @SearchString VARCHAR(200)=NULL,
								   @FirstRec INT =0,
								   @LastRec INT =0,
								   @DisplayStart INT =0,
								   @DisplayLength INT =0,
								   @Sortcol INT =0,
								   @SortDir varchar(10)=null
									 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertCustomerPO'
BEGIN
    IF @CustomerPOId=0
	BEGIN
	    SET @CustomerPOId=ISNULL((SELECT TOP 1 CustomerPOId+1 FROM CustomerPO ORDER BY CustomerPOId DESC),1) ;
		SET @PONo=@CustomerPOId;
	END
	ELSE 
	BEGIN
	    UPDATE CustomerPO SET IsActive =0 WHERE CustomerPOId=@CustomerPOId;
	END
	   INSERT INTO  CustomerPO
	                          (
							  [CustomerPOId]
							  ,[PONo]
							  ,[Date]
							  ,[PrePOId]
							  ,[CreatedBy]
							   )
					VALUES
							 (
							 @CustomerPOId,
							 @PONo,
							 @Date,
							 @PrePOId,
							 @CreatedBy
							 )
						SELECT '1'

END
ELSE IF @Action='GetCustomerPODtls'
BEGIN
set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;
     select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by            
							 case when @Sortcol=0 then A.CustomerPOId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.PONo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Date	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.PrePONo end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.PrePONo end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.InternalPODate	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.InternalPODate end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.CustomerName	end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.CustomerName end desc						    
                     ) as RowNum  
					 from (
								Select CP.CustomerPOId, CP.PONo, CP.Date ,PM.PrePONo, PM.InternalPODate, C.CustomerName,
								COUNT(*) over() as TotalCount  from CustomerPO CP
								inner join PrePOMain PM on PM.PrePOId=CP.PrePOId and PM.IsActive=1 
								inner join CustomerMaster C on C.CustomerId=PM.CustId and C.IsActive=1 
								where CP.IsActive=1 
						  )A where (@SearchString is null or A.PONo like '%' +@SearchString+ '%' or
									A.PrePONo like '%' +@SearchString+ '%' or A.InternalPODate like '%' +@SearchString+ '%' or
									A.CustomerName like '%' + @SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetPrePODtlsForCustomerPO'
BEGIN
    select PM.PrePOId, PM.PrePONo from PrePOMain PM
	left join CustomerPO CP on CP.PrePOId=PM.PrePOId and CP.IsActive=1
	where PM.IsActive=1 and  ((@CustomerPOId =0 and CP.PrePOId is null) or (@CustomerPOId<>0 and  CP.CustomerPOId=@CustomerPOId))
END
ELSE IF @Action='GetCustomerPODtlsById'
BEGIN
   SELECT PONo, Date, PrePOId FROM CustomerPO WHERE IsActive=1 AND CustomerPOId=@CustomerPOId;
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[CustomerSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CustomerSP]
						   (
						   @Action varchar(75)=null,
						   @CustomerId int=0,
						   @CustomerType varchar(20)=null,
						   @CustomerCode varchar(20)=null,
						   @CustomerName varchar(100)=null,
						   @PrintName varchar(100)=null,
						   @EmailId varchar(75)=null,
						   @TelephoneNo varchar(75)=null,
						   @ContactPerson varchar(50)=null,
						   @MobileNo varchar(20)=null,
						   @Fax varchar(20)=null,
						   @PaymentTermsId int =0,
						   @PaymentTermsDueDate varchar(20)=null,
						   @PANNo varchar(20)=null,
						   @IsTDSRequired bit =0,
						   @CreatedBy int =0,
						   @B_DoorNo varchar(200)=null,
						   @B_Block varchar(200)=null,
						   @B_StreetName varchar(200)=null,
						   @B_City int =0,
						   @B_State int =0,
						   @B_Country int =0,
						   @B_Pincode varchar(20)=null,
						   @B_GSTNo varchar(20)=null,
						   @S_DoorNo varchar(200)=null,
						   @S_Block varchar(200)=null,
						   @S_StreetName varchar(200)=null,
						   @S_City int =0,
						   @S_State int =0,
						   @S_Country int =0,
						   @S_Pincode varchar(20)=null,
						   @S_GSTNo varchar(20)=null,
						   @BankName varchar(75)=null,
						   @BankCode varchar(30)=null,
						   @AccountNo varchar(20)=null,
						   @SwiftCode varchar(20)=null,
						   @AccountName varchar(75)=null,
						   @IBan varchar(75)=null
						   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertCustomer'
BEGIN
    IF @CustomerId=0
	BEGIN
	   SET @CustomerId=isnull((SELECT TOP 1 CustomerId+1 FROM CustomerMaster ORDER BY CustomerId desc),1);
	    SET @CustomerCode=(select Format +  FORMAT(cast(CurrentNumber as int),'D3') from SerialNoFormats where Type=@CustomerType and IsActive=1);
		UPDATE SerialNoFormats set CurrentNumber=CurrentNumber+1 where type=@CustomerType and IsActive=1;         
	END
	ELSE
	BEGIN
	   UPDATE CustomerMaster SET IsActive=0 WHERE CustomerId=@CustomerId
	   UPDATE CustBankDtls SET IsActive=0 WHERE CustomerId=@CustomerId;
	   UPDATE CustAddressDtls SET IsActive=0 WHERE CustomerId=@CustomerId;
	END
	   INSERT INTO [dbo].[CustomerMaster]
							   (
							   [CustomerId]
							   ,[CustomerType]
							   ,[CustomerCode]
							   ,[CustomerName]
							   ,[PrintName]
							   ,[EmailId]
							   ,[TelephoneNo]
							   ,[ContactPerson]
							   ,[MobileNo]
							   ,[Fax]
							   ,[PaymentTermsId]
							   ,[PaymentTermsDueDate]
							   ,[PANNo]
							   ,[IsTDSRequired]
							   ,[CreatedBy]
							   )
						VALUES
							    (
								@CustomerId,
								@CustomerType,
								@CustomerCode,
								@CustomerName,
								@PrintName,
								@EmailId,
								@TelephoneNo,
								@ContactPerson,
								@MobileNo,
								@Fax,
								@PaymentTermsId,
								@PaymentTermsDueDate,
								@PANNo,
								@IsTDSRequired,
								@CreatedBy
								)
		INSERT INTO [dbo].[CustAddressDtls]
							   (
							    [CustomerId]
							   ,[B_DoorNo]
							   ,[B_Block]
							   ,[B_StreetName]
							   ,[B_City]
							   ,[B_State]
							   ,[B_Country]
							   ,[B_Pincode]
							   ,[B_GSTNo]
							   ,[S_DoorNo]
							   ,[S_Block]
							   ,[S_StreetName]
							   ,[S_City]
							   ,[S_State]
							   ,[S_Country]
							   ,[S_Pincode]
							   ,[S_GSTNo]
							   ,[CreatedBy]
							   )
					   VALUES
					          (
							   @CustomerId,
							   @B_DoorNo,
							   @B_Block,
							   @B_StreetName,
							   @B_City,
							   @B_State,
							   @B_Country,
							   @B_Pincode,
							   @B_GSTNo,
							   @S_DoorNo,
							   @S_Block,
							   @S_StreetName,
							   @S_City,
							   @S_State,
							   @S_Country,
							   @S_Pincode,
							   @S_GSTNo,
							   @CreatedBy
							   )
		INSERT INTO CustBankDtls
								(
								CustomerId,
								BankName,
								BankCode,
								AccountNo,
								SwiftCode,
								AccountName,
								IBan,
								CreatedBy
								)
					   VALUES
					           (
							   @CustomerId,
							   @BankName,
							   @BankCode,
							   @AccountNo,
							   @SwiftCode,
							   @AccountName,
							   @IBan,
							   @CreatedBy
							   )

				SELECT '1'
END
ELSE IF @Action='GetCustomerDtlsByType'
BEGIN
    SELECT C.CustomerId,C.CustomerName,CA.B_GSTNo,C.MobileNo,C.EmailId,CM.Name as City FROM CustomerMaster C
	left join CustAddressDtls CA on CA.CustomerId = C.customerId and CA.isActive =1
	left join CityMaster CM on CM.ID =CA.B_city
	where C.IsActive=1 and C.CustomerType=@CustomerType order by C.CustomerId desc;    
END
ELSE IF @Action='GetCustomerDtlsById'
BEGIN
     SELECT C.CustomerType,C.CustomerCode,C.CustomerName,C.PrintName,C.EmailId,C.TelephoneNo,C.ContactPerson,
	 C.MobileNo,C.Fax,C.PaymentTermsId,C.PaymentTermsDueDate,C.PANNo,C.IsTDSRequired
	 FROM CustomerMaster C
	 WHERE C.IsActive=1 AND C.CustomerId=@CustomerId;

	 SELECT C.BankName,C.BankCode,C.AccountNo,C.SwiftCode,C.AccountName,C.IBan FROM CustBankDtls C
	 where C.IsActive=1 and C.CustomerId =@CustomerId;

	  SELECT C.B_DoorNo,C.B_Block,C.B_StreetName,C.B_City,C.B_State,C.B_Country,C.B_Pincode,C.B_GSTNo,
	  C.S_DoorNo,C.S_Block,C.S_StreetName,isnull(C.S_City,0) as S_City,isnull(C.S_State,0) as S_State,isnull(C.S_Country,0) as S_Country,
	  C.S_Pincode,C.S_GSTNo
	  FROM CustAddressDtls C
	  where C.IsActive=1 and C.CustomerId =@CustomerId;
END


COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[DCEntrySP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DCEntrySP]
					     (
						 @Action varchar(75)=null,
						 @DCId int =0,
						 @POType varchar(20)=null,
						 @DCNo varchar(20)=null,
						 @DCDate varchar(20)=null,
						 @SupplierId int =0,
						 @DespatchThrough varchar(100)=null,
						 @RequiredByDate varchar(20)=null,
						 @NatureOfProcess varchar(100)=null,
						 @Types varchar(20)=null,
						 @DeliverySchedule varchar(20)=null,
						 @VehicleNo varchar(20)=null,
						 @AppxValue varchar(20)=null,
						 @DrawingEnclosed varchar(10)=null,
						 @Remarks varchar(max)=null,
						 @Status varchar(20)=null,
						 @CreatedBy int =0,
						 @DCEntrySub DCEntrySub READONLY,
						@SearchString VARCHAR(200)=NULL,
						@FirstRec INT =0,
						@LastRec INT =0,
						@DisplayStart INT =0,
						@DisplayLength INT =0,
						@Sortcol INT =0,
						@SortDir varchar(10)=null,
						@Year varchar(20)=null
						 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertDC'
BEGIN
   Set @DCId=ISNULL((SELECT TOP 1 DCId+1 FROM DCEntryMain ORDER BY DCId DESC),1);
   set @dcNo=( select format + ' ' + cast(CurrentNumber as varchar)  from SerialNoFormats where type='DC' and year=@Year)
   update SerialNoFormats set CurrentNumber=CurrentNumber+1 where type='DC' and year=@Year
   INSERT INTO DCEntryMain
						 (
						 [DCId]
						,[POType]
						,[DCNo]
						,[DCDate]
						,[SupplierId]
						,[DespatchThrough]
						,[RequireByDate]
						,[NatureOfProcess]
						,[Types]
						,[DeliverySchedule]
						,[VehicleNo]
						,[AppxValue]
						,[DrawingEnclosed]
						,[Remarks]
						,[CreatedBy]
						)
				VALUES
						(
						@DCId,
						@PoType,
						@DCNo,
						@DCDate,
						@SupplierId,
						@DespatchThrough,
						@RequiredByDate,
						@NatureOfProcess,
						@Types,
						@DeliverySchedule,
						@VehicleNo,
						@AppxValue,
						@DrawingEnclosed,
						@Remarks,
						@CreatedBy
						)
   INSERT INTO [dbo].[DCEntrySub]
					   ([DCId]
					   ,[PrePOId]
					   ,[ItemId]
					   ,[RouteEntryId]
					   ,[RoutLineNo]
					   ,[OperationId]
					   ,[RawMaterialId]
					   ,[DimensionId]
					   ,[StockFrom]
					   ,[Remarks]
					   ,[OutQty]
					   ,[QtyInKgs]
					   ,[Qty]
					   ,[InwardBalQty]
					   ,[CreatedBy]
					   )
			SELECT   @DCId
			         ,[PrePOId]
					,[ItemId]
					,[RouteEntryId]
					,[RoutLineNo]
					,[OperationId]
					,[RawMaterialId]
					,[DimensionId]
					,[StockFrom]
					,[Remarks]
					,[OutQty]
					,[QtyInKgs]
					,[Qty]
					,[Qty]
					,@CreatedBy  FROM @DCEntrySub;

		
		Update P set P.AccQty =Cast(isnull(P.AccQty,'0') as decimal(18,3)) - Cast(isnull(t.OutQty,'0') as decimal(18,3))  from POProcessQtyDetails P
		inner join @DCEntrySub t on P.RouteEntryId=T.RouteEntryId and P.RoutLineNo=T.RoutLineNo-1  and P.IsActive=1;
		

		Update RM set RM.QtyKgs=cast(isnull(RM.QtyKgs,'0') as decimal(18,3)) - cast(isnull(d.QtyInKgs,'0') as decimal(18,3)) ,
		RM.QtyNos=cast(RM.QtyNos as decimal(18,3)) - cast(d.QtyNos as decimal(18,3)) 
		from RMDimensionWiseStock RM 			
		inner join (
			Select DimensionId , sum(cast(isnull(T.QtyInKgs,'0') as decimal(18,3))) as QtyInKgs ,sum(cast(isnull(T.OutQty,'0') as decimal(18,2))) as QtyNos   
			from @DCEntrySub T where T.RoutLineNo=1 group by T.DimensionId
			) d on d.DimensionId = RM.RMDimensionId and RM.isActive=1;
     
IF @POType='CustomerPO'
BEGIN
      Update S set S.Status='In Progress' from PrePoSub S
	  inner join @DCEntrySub t on S.PrePoId=t.PrePoId and S.ItemId=t.ItemId and S.isActive=1; 

	  Update M set M.Status='In Progress' from PrePOMain M
      inner join @DCEntrySub t on M.PrePoId=t.PrePoId and M.isActive=1;
END
ELSE
BEGIN
    Update S set S.Status='In Progress' from JobOrderPOSub S
	inner join @DCEntrySub t on S.JobOrderPOId=t.prepoId and S.JobOrderpoSubId=t.itemId and S.isActive=1; 

	Update M set M.Status='In Progress' from JobOrderPOMain M
	inner join @DCEntrySub t on M.jobOrderPOId=t.prepoId and M.isActive=1; 
END 
		
		SELECT '1'
END

ELSE IF @Action= 'GetDCEntryDtls'
BEGIN
	Set @FirstRec=@DisplayStart;
	Set @LastRec=@DisplayStart+@DisplayLength;

			select * from (
				Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
								 case when @Sortcol=0 then A.DCId end  desc,
								 case when (@SortCol =1 and  @SortDir ='asc')  then A.DCNo	end asc,
								 case when (@SortCol =1 and  @SortDir ='desc') then A.DCNo	end desc ,
								 case when (@SortCol =2 and  @SortDir ='asc')  then A.DCDate	end asc,
								 case when (@SortCol =2 and  @SortDir ='desc') then A.DCDate	end desc,
								 case when (@SortCol =3 and  @SortDir ='asc')  then A.VendorName end asc,
								 case when (@SortCol =3 and  @SortDir ='desc') then A.VendorName end desc,
								 case when (@SortCol =4 and  @SortDir ='asc')  then A.B_GSTNo end asc,
								 case when (@SortCol =4 and  @SortDir ='desc') then A.B_GSTNo end desc,
								 case when (@SortCol =5 and  @SortDir ='asc')  then A.DespatchThrough	end asc,
								 case when (@SortCol =5 and  @SortDir ='desc') then A.DespatchThrough end desc,	
								 case when (@SortCol =6 and  @SortDir ='asc')  then A.RequireByDate end asc,
								 case when (@SortCol =6 and  @SortDir ='desc') then A.RequireByDate end desc				    
						 ) as RowNum  
						 from (						 
						Select DC.DCId, DC.DCNo, DC.DCDate,C.CustomerName as VendorName,CA.B_GSTNo, DC.DespatchThrough, DC.RequireByDate,
						COUNT(*) over() as TotalCount  from DCEntryMain DC
						inner join CustomerMaster C on C.CustomerId=DC.SupplierId and C.IsActive=1 
						left join CustAddressDtls CA on CA.CustomerId=DC.SupplierId and CA.IsActive=1
						where DC.IsActive=1 and DC.POType=@POType
						 )A where (@SearchString is null or A.DCNo like '%' +@SearchString+ '%' or
										A.DCDate like '%' +@SearchString+ '%' or A.VendorName like '%' +@SearchString+ '%' or
										A.B_GSTNo like  '%' +@SearchString+ '%' or
										A.DespatchThrough like '%' + @SearchString+ '%' or A.RequireByDate like '%' +@SearchString+ '%')
				) A where  RowNum > @FirstRec and RowNum <= @LastRec 

END

ELSE IF @Action='GetVendorDCDtlsById'
BEGIN
	select DC.DCNo,DC.DCDate,DC.SupplierId,DC.DespatchThrough,DC.RequireByDate,DC.NatureOfProcess,DC.Types,DC.DeliverySchedule,
	DC.VehicleNo, DC.AppxValue,DC.DrawingEnclosed,DC.Remarks from DCEntryMain DC
	where DC.IsActive=1 and  DC.DCId=@DCId;

	Select DS.PrePOId, ISNULL(PM.PrePONo,JM.PONo) as PrePONo,  DS.ItemId,
	case when @POType='CustomerPO' then IM.PartNo+'-'+IM.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
	DS.RouteEntryId,DS.RoutLineNo,DS.OperationId,DS.RawMaterialId,
	RM.CodeNo+'-' + RM.Description as RawMaterial,RP.Weight,
	DS.DimensionId,RW.Text1 +'-' + RW.Value1 + case when RW.Text2 <>'' or RW.Text2 is not  null then ' * ' + RW.Text2+ '-'+RW.Value2 +' * ' else ' * ' end +RW.Text3 +'-' +RW.Value3 as Dimension,
	DS.StockFrom,DS.Remarks,DS.OutQty,DS.QtyInKgs,DS.Qty,
	cast(DS.RoutLineNo as varchar)+'-'+O.OperationName as Operation
	from DCEntrySub DS
	left join PrePOMain PM on @POType='CustomerPO' and  PM.PrePOId =DS.PrePOId and PM.isActive=1
	left join JobOrderPOMain JM on   @POType='JobOrderPO' and  JM.JobOrderPOId =DS.PrePOId and JM.isActive=1
	left join RMPlanning RP on @POType='CustomerPO' and RP.PrePOId = DS.PrePOId and RP.ItemId =DS.ItemId and RP.IsActive=1 
	left join RMDimensionWiseStock RW on @POType='CustomerPO' and DS.RoutLineNo=1 and RW.RMDimensionId = DS.DimensionId and RW.IsActive=1
	left join ItemMaster IM on @POType='CustomerPO' and IM.ItemId=DS.ItemId and IM.IsActive=1
	left join RawMaterial RM on @POType='CustomerPO' and  RM.RawMaterialId =DS.RawMaterialId and RM.IsActive=1 
	inner join OperationMaster O on O.OperationId=DS.OperationId and O.IsActive=1
	left join JobOrderPOSub JS on @POType='JobOrderPO' and JS.JobOrderPOId=DS.PrePOId and JS.JobOrderPOSubId=DS.ItemId and JS.IsActive=1 
	where DS.IsActive=1 and DS.DCId=@DCId;
END

ELSE IF @Action = 'DeleteDCEntry'
BEGIN
	update DCEntryMain set IsActive = 0 where DCId=@DCId and IsActive = 1
	update DCEntrySub set IsActive = 0 where DCId=@DCId and IsActive = 1
	select 1
END	    
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[DPREntrySP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DPREntrySP]
							(
							@Action varchar(75)=null,
							@DPRId int =0,
							@DPRNo varchar(20)=null,
							@DPRDate varchar(20)=null,
							@DPRKey varchar(20)=null,
							@POType varchar(20)=null,
							@PrePOId int =0,
							@ItemId int =0,
							@RouteEntryId int =0,
							@RoutLineNo  int =0,
							@OperationId int=0,
							@ShiftId int =0,
							@MachineId int=0,
							@StartTime varchar(20)=null,
							@EndTime varchar(20)=null,
							@Qty varchar(20)=null,
							@ContinueShift varchar(20)=null,
							@ContShiftKey varchar(5)=null,
							@Rework varchar(20)=null,
							@ProdEmpId int =0,
							@InspectionStatus varchar(20)=null,
							@FirstPieceInspId INT =0,
							@CreatedBy int=0,
							@QCDate varchar(20)=null,
							@DrgNo varchar(50)=null,
							@QCFrom varchar(20)=null,
							@QCTo varchar(20)=null,
							@PreparedBy int =0,
							@Attachments varchar(max)=null,
							@Head1 varchar(50)=null,
							@Head2 varchar(50)=null,
							@Head3 varchar(50)=null,
							@Head4 varchar(50)=null,
							@Head5 varchar(50)=null,
							@Head6 varchar(50)=null,
							@QCStatus VARCHAR(20)=NULL,
							@FirstPieceInspectionSub FirstPieceInspectionSub READONLY,
							@PrevDPRId int =0,
							@PrevContShiftKey varchar(20)=NULL,
							@ConvFactor varchar(20)=null,
							@DPRReasonDtls DPRReasonDtls readonly,
							@AccQty varchar(20)=null,
							@RejQty varchar(20)=null,
							@Reason varchar(max)=null,
							@NotificationId int =0,
							@PONo varchar(20)=null,
							@OperationName varchar(100)=null,
							@ItemName varchar(100)=null,
							@FinalRoutLineNo INT =0,
							@FinalProcessProdQty VARCHAR(20)=NULL,
							@FirstRec int=0,
							@SortDir varchar(10)=null,
							@SearchString varchar(200)=null,
							@DisplayStart int=0,
							@DisplayLength int=0,
							@SortCol int=0,
							@LastRec int=0
)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertDPR'
BEGIN
        SET @DPRId=ISNULL((SELECT TOP 1 DPRId+1 FROM DPREntry ORDER BY DPRId DESC),1);
		SET @DPRNo =@DPRId;
		SET @FirstPieceInspId=(SELECT TOP 1 FirstPieceInspId FROM DPREntry WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RoutLineNo and MachineId=@MachineId AND DPRKey IN ('Setting','Production') order by DPRId desc);
		INSERT INTO DPREntry
							(
							DPRId,
							DPRNo,
							DPRDate,
							DPRKey,
							POType,
							PrePOId,
							ItemId,
							RouteEntryId,
							RoutLineNo,
							OperationId,
							ShiftId,
							MachineId,
							StartTime,
							EndTime,
							Qty,
							ContinueShift,
							Rework,
							ProdEmpId,
							InspectionStatus,
							FirstPieceInspId,
							CreatedBy
							)
			      VALUES
						   (
							@DPRId,
							@DPRNo,
							@DPRDate,
							@DPRKey,
							@POType,
							@PrePOId,
							@ItemId,
							@RouteEntryId,
							@RoutLineNo,
							@OperationId,
							@ShiftId,
							@MachineId,
							@StartTime,
							@EndTime,
							@Qty,
							@ContinueShift,
							@Rework,
							@ProdEmpId,
							'false',
							@FirstPieceInspId,
							@CreatedBy
							)
		INSERT INTO DPRReasonDtls
								  (
								  DPRId,
								  ReasonId,
								  FromTime,
								  ToTime,
								  CreatedBy
								  )
						
			
						SELECT    @DPRId,
								  ReasonId,
								  FromTime,
								  ToTime,
								  @CreatedBy from 
								  @DPRReasonDtls;


		SELECT TOP 1  @PrevDPRId=DPRId , 
					  @PrevContShiftKey=ContinueShift
		 FROM DPREntry WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RoutLineNo AND MachineId=@MachineId AND IsActive=1 AND DPRId<>@DPRId order by DPRId desc;
		 
		  /*
		  WE NEED TO REDUCE THE QTY FROM POPROCESSQTYDETAILS AS WE HAVE USED IT AS WE HAVE TAKEN FROM 
		  THE PREVIOUS PROCESS FOR PRODUCING THE CURRENT PROCESS.
		  IF THE QTY IS PRODUCED THROUGH CONTINUE SHIFT CONCEPT MEANS(CURRENT DPR IS CONTINUE SHIFT OR CONTINUSION OF PREVIOUS DPR,
		  ) WE ARE REDUCING ONLY FOR FIRST TIME. BECAUSE FOR THE SECOND , THIRD, .. TIME MEANS,
		   IT IS A CONTINUSION OF FIRST TIME. SO WE DONT NEED TO REDUCE IT AGAIN. IF IT IS REDUCED MEANS , DEFINITELY IT WONT WORK...

		   IF @PrevDPRId IS NULL MEANS IT INDICATES THAT IS TOTALLY A NEW ENTRY FOR THAT RouteEntryId,RoutLineNo,MachineId. 
		   AS IT A NEW ENTRY , WE ARE REDUCING.
		   IF @PrevDPRId CONTAINS SOME DPRID , BUT IF @PrevContShiftKey='FALSE' THEN ALSO IT IS CONSIDERED AS NEW ENTRY. 
		   BECAUSE THIS IS NOT A CONTINUSUION OF PREVIOUS PRODUCTION.
		   IF @PrevDPRId CONTAINS SOME DPRID , BUT IF @PrevContShiftKey='TRUE' THEN IT IS A CONTINUSUION OF PREVIOUS PRODUCTION.
		   SO WE DONT NEED TO REDUCE THE POPROCESSQTY AS WE HAVE REDUCED ON 1ST TIME.
		  */

	     IF  @PrevDPRId IS NULL or @PrevDPRId=0 OR @PrevContShiftKey='false'
		 BEGIN
		     
		      UPDATE POProcessQtyDetails Set AccQty=CAST(ISNULL(AccQty,'0')  AS FLOAT) - CASE WHEN @Rework='false' then  cast(isnull(@Qty ,'0') as float) else cast('0' as float) end, 
			                                 ReworkQty=CAST(ISNULL(ReworkQty,'0')  AS FLOAT) - CASE WHEN @Rework='true' then  cast(isnull(@Qty ,'0') as float) else cast('0' as float) end 
			  where RouteEntryId=@RouteEntryId and RoutLineNo= @RoutLineNo-case when @Rework='false' then 1 else 0 end  and IsActive=1 --and @Rework='false';			 
		 END
		 IF @PrevContShiftKey='true'
		 BEGIN
		    UPDATE DPREntry SET ContShiftKey='Yes' where DPRId=@PrevDPRId and IsActive=1;
		 END
			SELECT '1'
END
ELSE IF @Action='InsertFirstPieceInspection'
BEGIN

/*
  STEP 1: INSERTING INTO First PieceInspection Details TABLE
  STEP 2: UPDATING INSPECTION STATUS IN  DPR THAT QC HAS 
  STEP 3: IF QC IS REJECTED , INSERTING INTO NOTIFICATION TABLE
  STEP 4:INSERTING OR UPDATING INTO POPROCESSQTY DETAILS WITH CONVERSION FACTOR
  STEP 5:IF ALL PROCESS HAS COMPLETED THEN ADDING THIS INTO ITEM STOCK
  STEP 6:UPDATING STATUS TO CLOSED IF PRODQTY REACHED POQTY IN PREPOSUB , PREPOMAIN INCASE OF CUSTOMERPO 
         AND JOBORDERPOMAIN  AND JOBORDERPOSUB IN CASE OF JOBORDERPO 
*/
/*STEP 1: */
     SET @FirstPieceInspId=ISNULL((SELECT TOP 1 FirstPieceInspId+1 FROM FirstPieceInspectionMain ORDER BY  FirstPieceInspId DESC ),1);
	 INSERT INTO FirstPieceInspectionMain
										 (
										 FirstPieceInspId,
										 QCDate,
										 DPRId,
										 DrgNo,
										 SetupDate,
										 SetupFrom,
										 SetupTo,
										 QCFrom,
										 QCTo,
										 PreparedBy,
										 Attachments,
										 Reason,
										 Head1,
										 Head2,
										 Head3,
										 Head4,
										 Head5,
										 Head6,
										 QCStatus,
										 CreatedBy
										 )
								VALUES
									   (
										@FirstPieceInspId,
										@QCDate,
										@DPRId,
										@DRGNo,
										@DPRDate,
										@StartTime,
										@EndTime,
										@QCFrom,
										@QCTo,
										@PreparedBy,
										@Attachments,
										@Reason,
										@Head1,
										@Head2,
										@Head3,
										@Head4,
										@Head5,
										@Head6,
										@QCStatus,
										@CreatedBy
										)
	 INSERT INTO FirstPieceInspectionSub
										(
										FirstPieceInspId,
										DPRId,
										Parameter,
										Specification,
										Instrument,
										ToolSetting,
										Value1,
										Value2,
										Value3,
										Value4,
										Value5,
										Value6,
										CreatedBy
										)
							SELECT      @FirstPieceInspId,
									    @DPRId,
										Parameter,
										Specification,
										Instrument,
										ToolSetting,
										Value1,
										Value2,
										Value3,
										Value4,
										Value5,
										Value6,
										@CreatedBy FROM @FirstPieceInspectionSub;
/*STEP 2: */
     UPDATE DPREntry Set InspectionStatus='true', FirstPieceInspId=@FirstPieceInspId where DPRId=@DPRId;
	

	Select Top 1 @RouteEntryId=D.RouteEntryId, @RoutLineNo= D.RoutLineNo, 
				@POType=D.POType,@PrePOId=D.PrePoId,@ItemId=D.ItemId,
				@OperationId=D.OperationId,
				@AccQty=case when @QCStatus='Approved' then D.Qty else '0' end ,
				@RejQty=case when @QCStatus='Rejected' then D.Qty else '0' end 
    from DPREntry D
	where D.IsActive=1 and D.DPRId=@DPRId; 
  /*STEP 3: */  
	 IF @QCStatus='Rejected'
	 BEGIN
			 IF @POType='CustomerPO'
			 BEGIN
				 SET @PONo=(SELECT TOP 1 PrePONo FROM PrePOMain where IsActive=1 and PrePOId=@PrePOId);
				 SET @ItemName=(SELECT PartNo + ' - ' + Description FROM ItemMaster where IsActive=1 and ItemId=@ItemId);
			 END
			 ELSE
			 BEGIN 
				 SET @PONo=(SELECT TOP 1 PONo FROM JobOrderPOMain where IsActive=1 and JobOrderPOId=@PrePOId);
				 SET @ItemName=(SELECT PartNo + ' - ' + ItemName FROM JobOrderPOSub where IsActive=1 and JobOrderPOId=@PrePOId and JobOrderPOSubId=@ItemId);
			 END
			  SET @OperationName =(SELECT TOP 1 OperationName FROM OperationMaster O WHERE O.IsActive=1 AND O.OperationId=@OperationId);
			  SET @NotificationId =ISNULL((SELECT TOP 1 NotificationId +1 FROM NotificationDtls ORDER BY NotificationId desc),1);
			  INSERT INTO NotificationDtls
										  (
											NotificationId,
											NotificationKey,
											KeyId,
											Details,
											CreatedBy
											)
									VALUES
									       (
										   @NotificationId,
										   'First Piece Inspection Rejection',
										   @FirstPieceInspId,
										   case when  @POType='CustomerPO' then 'Pre PO No - ' else 'Job Order PO No - ' end + @PONo +' of Item - ' + @ItemName +
										   ' of Process - P' + CAST(@RoutLineNo as varchar) + ' - ' + @OperationName +' is rejected for the reason of ' + ISNULL(@Reason ,''),
										   @CreatedBy
										   )
	 END
  /*STEP 4: */  
	SET @ConvFactor=isnull((SELECT TOP 1 CASE WHEN  ConvFact='' THEN '1' ELSE ConvFact end FROM RouteCardEntry WHERE RouteEntryId =@RouteEntryId AND RoutLineNo=@RoutLineNo AND IsActive=1 ),'1');
     IF NOT EXISTS(SELECT TOP 1 RouteEntryId  FROM POProcessQtyDetails WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RoutLineNo  AND IsActive=1)
	 BEGIN
		 INSERT INTO POProcessQtyDetails
									(
									POType,
									PrePOId,
									ItemId,
									RouteEntryId,
									RoutLineNo,
									TotalAccQty,
									AccQty,
									ReworkQty,
									RejQty,
									CreatedBy
									)
						 VALUES
								  (
								  @POType,
								  @PrePOId,
								  @ItemId,
								  @RouteEntryId,
								  @RoutLineNo,
								  cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'0') as float),
								  cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'0') as float),
								  '0',
								   cast(isnull(@RejQty ,'0') as float) * CAST(isnull(@ConvFactor,'0') as float),
								  @CreatedBy
								  )
     END
   ELSE
   BEGIN 
       UPDATE POProcessQtyDetails SET AccQty=CAST(ISNULL(AccQty,'0')  AS FLOAT) + (cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'0') as float)),
									  TotalAccQty=CAST(ISNULL(TotalAccQty,'0')  AS FLOAT) + (cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'0') as float)),
									  RejQty=CAST(ISNULL(RejQty,'0')  AS FLOAT) + (cast(isnull(@RejQty ,'0') as float) * CAST(isnull(@ConvFactor,'0') as float))
	   WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RoutLineNo AND IsActive=1 
      
   END
 /*STEP 5 & 6: */
IF @QCStatus='Approved'
BEGIN
    SET @FinalRoutLineNo =(SELECT TOP 1 RoutLineNo FROM RouteCardEntry R where R.IsActive=1 and RouteEntryId=@RouteEntryId order by RoutLineNo desc);
	set @FinalProcessProdQty=(SELECT TOP 1 AccQty FROM POProcessQtyDetails P WHERE P.IsActive=1 AND P.RouteEntryId=@RouteEntryId AND RoutLineNo=@FinalRoutLineNo);
	IF @POType='CustomerPO'
	BEGIN
	    UPDATE PrePOSub  SET Status='Closed' , ClosedOn=getDate()
		WHERE PrePOId=@PrePOId and ItemId=@ItemId AND ISACTIVE=1   and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE PM  SET Status='Closed' , ClosedOn=getDate() 
		FROM PrePOMain PM
		INNER JOIN (
				SELECT 	COUNT(CASE when PS.Status='Closed' then 1 else null end ) as ClosedCount, Count(PS.ItemId) as TotalCount
				FROM PrePOSub PS
				WHERE PS.IsActive=1 and PS.PrePOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount 
	     IF @RoutLineNo=@FinalRoutLineNo
		 BEGIN
		      IF EXISTS(SELECT TOP 1 ItemId FROM ItemStock WHERE ItemId=@ItemId and IsActive=1 )
			  BEGIN
			     UPDATE ItemStock SET Qty = CAST(ISNULL(QTY,'0') AS decimal(18,2)) + (cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'0') as float))
				 WHERE ItemId=@ItemId and IsActive=1 
			  END
			  ELSE
			  BEGIN
				   INSERT INTO ItemStock
									(
									ItemId,
									Qty,
									CreatedBy
									)
						VALUES
								  (
								  @ItemId,
								  cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'0') as float),
								  @CreatedBy
								  )
			      
			  END
		 END
	END
	ELSE
	BEGIN
	    UPDATE JobOrderPOSub  SET Status='Closed' , ClosedOn=getDate()
		WHERE JobOrderPOId=@PrePOId and JobOrderPOSubId=@ItemId AND ISACTIVE=1   and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE JM  SET Status='Closed' , ClosedOn=getDate() 
		FROM JobOrderPOMain JM
		INNER JOIN (
				SELECT 	COUNT(CASE when JS.Status='Closed' then 1 else null end ) as ClosedCount, Count(JS.JobOrderPOSubId) as TotalCount
				FROM JobOrderPOSub JS
				WHERE JS.IsActive=1 and JS.JobOrderPOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount  
	END
END     
									   
	 SELECT '1'
END
ELSE IF @Action='GetMachineListForDPR'
BEGIN
     IF @DPRKey='Setting'
	 BEGIN
	        SELECT cast(RCM.value as int) as MachineId,M.MachineCode +' - ' + M.MachineName as MachineCode_Name, RC.Setup,RC.Cycle ,
			'' as SetupDate,
			'' as SetupFrom,'' as SetupTo,'' as  StartDate, '' as StartTime,'' as EndTime,'' as QCDate, '' as QCFrom,'' as QCTo	
			
			 FROM RouteCardMachine RC 
			cross apply fn_split (RC.MachineIds, ',') RCM
			inner join MachineDetails M on M.MachineId =RCM.value and M.IsActive=1 
			Where RC.RouteEntryId=@RouteEntryId and RC.RoutLineNo=@RoutLineNo and RC.IsActive=1 
	 END
	 ELSE IF @DPRKey='Production'
	 BEGIN
	        Select A.MachineId,M.MachineCode +' - ' + M.MachineName as MachineCode_Name,A.Setup,A.Cycle,
			F.SetupDate, F.SetupFrom,F.SetupTo,case when A.DPRKey='Production' then  A.DPRDate else '' end  as StartDate,
			case when A.DPRKey='Production' then  A.StartTime else '' end  as StartTime,
			case when A.DPRKey='Production' then  A.EndTime else '' end  as EndTime, F.QCDate,F.QCFrom,F.QCTo  from (
			Select  D.MachineId,RC.Setup,RC.Cycle,D.DPRDate, D.StartTime,D.EndTime, D.DPRId,(MAX(D.DPRId) OVER (PARTITION BY D.MachineId)) AS MDPRId,D.DPRKey
			from DPREntry D
			inner join RouteCardMachine RC cross apply fn_split (RC.MachineIds, ',') RCM on RC.RouteEntryId=D.RouteEntryId 
										   and RC.RoutLineNo=D.RoutLineNo and RC.IsActive=1 and RCM.value=D.MachineId 
			where D.IsActive =1
			and D.RouteEntryId=@RouteEntryId and D.RoutLineNo=@RoutLineNo
			)A
			left join FirstPieceInspectionMain F on F.DPRId=A.DPRId and F.IsActive=1
			inner join MachineDetails M on M.MachineId=A.MachineID and M.IsActive=1 
			 where A.DPRId=A.MDPRId and (A.DPRKey='Production' or F.QCStatus='Approved')
	 END
	 ELSE IF @DPRKey='DirectProduction'
	 BEGIN 
	    SELECT M.MachineId,M.MachineCode +' - ' + M.MachineName as MachineCode_Name,0 as Setup,0 as Cycle,		
		'' as SetupDate,
	    '' as SetupFrom,'' as SetupTo,'' as  StartDate, '' as StartTime,'' as EndTime,'' as QCDate, '' as QCFrom,'' as QCTo	
		FROM MachineDetails M
		WHERE M.IsActive=1 and M.MachineId=226
	 END
END
ELSE IF @Action='GetProdDtlsByBarcode'
BEGIN
    SELECT RC.RoutCardNo,RC.WorkPlace, RC.POType,RC.PrePOId,RC.ItemId,RC.RouteEntryId,RC.RoutLineNo,RC.OperationId,
	ISNULL(PM.PrePONo,JM.PONo) as PrePONo,	
	isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
	RM.CodeNo+'-' + RM.Description as RawMaterial,RC.RawMaterialId,
	O.OperationName as Operation,RC.ProcessQty,isnull(PS.Qty,JS.Qty) as POQty
	FROM RouteCardEntry RC
	left join PrePOMain PM on RC.POType='CustomerPO' and  PM.PrePOId =RC.PrePOId and PM.isActive=1
	left join PrePOSub PS on RC.POType='CustomerPO' and  PS.PrePOId =RC.PrePOId  and PS.ItemId=RC.ItemId and PS.isActive=1
	left join JobOrderPOMain JM on   RC.POType='JobOrderPO' and  JM.JobOrderPOId =RC.PrePOId and JM.isActive=1
	left join ItemMaster I on RC.POType='CustomerPO' and I.ItemId=RC.ItemId and I.IsActive=1
	left join RawMaterial RM on RC.POType='CustomerPO' and  RM.RawMaterialId =RC.RawMaterialId and RM.IsActive=1
	left join JobOrderPOSub JS on RC.POType='JobOrderPO' and JS.JobOrderPOId=RC.PrePOId and JS.JobOrderPOSubId=RC.ItemId and JS.IsActive=1 
	inner join OperationMaster O on O.OperationId=RC.OperationId and O.IsActive=1
	WHERE RC.IsActive=1 AND RC.RouteEntryId=@RouteEntryId AND RC.RoutLineNo=@RoutLineNo; 
	
	Select PO.ReworkQty,PO.RejQty,PO.TotalAccQty  as FinalQty ,
	CAST(ISNULL(PO.TotalAccQty,'0') as decimal) + CAST(ISNULL(PO.ReworkQty,'0') as decimal)+CAST(ISNULL(PO.RejQty,'0') as decimal) as ProducedQty
	from POProcessQtyDetails PO
	where PO.IsActive=1   and PO.RouteEntryId=@RouteEntryId and PO.RoutLineNo=@RoutLineNo;

	Select PO.AccQty as QtyAvailableForProd from POProcessQtyDetails PO
	where PO.IsActive=1 and PO.RouteEntryId=@RouteEntryId and PO.RoutLineNo=@RoutLineNo-1;

	Select sum(CAST(isnull(D.Qty,'0') as decimal)) as QCPending from DPREntry D
	where D.IsActive=1 and D.InspectionStatus='false' and D.ContinueShift='false';
END
ELSE IF @Action='GetPendingFirstPieceInsDtls'
BEGIN
    Select D.DPRId,ISNULL(PM.PrePONo,JM.PONo) as PrePONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
	M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
	D.RouteEntryId as RouteCardNo,D.RoutLineNo, O.OperationCode +' - ' + O.OperationName as Operation, 
	D.DPRDate as SettingDate,D.StartTime as SettingFrom,D.EndTime as SettingTo ,E.EmpName as SettingBy
	 from DPREntry D
	inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 
	inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
	inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
	left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
	left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
	left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
	left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1 
where D.IsActive=1 and D.DPRKey='Setting' and D.ContinueShift='false' and D.InspectionStatus='false' and (@DPRId=0 or D.DPRId=@DPRID)
END
ELSE IF @Action='GetDPRDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DPRId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.DPRKey	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.DPRKey	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.DPRNo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DPRNo end desc,	
			                 case when (@SortCol =3 and  @SortDir ='asc')  then A.DPRDate	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.DPRDate	end desc ,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.POType	end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PONo	end desc,
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.ItemDescription end desc,
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.ProdEmployee end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.ProdEmployee end desc,	
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.Operation end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.Operation end desc,		
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.ProdQty end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.ProdQty end desc
                     ) as RowNum  
					 from (	
							Select D.DPRId ,D.DPRKey, D.DPRNo,D.DPRDate, D.POType,
							ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,E.EmpName as ProdEmployee,
							D.Qty as ProdQty,S.ShiftName,
							COUNT(*) over() as TotalCount
							from DPREntry D 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
							inner join ShiftMaster S on S.ShiftId=D.ShiftId and S.IsActive=1 														
							where D.IsActive=1 
					    )A where (@SearchString is null  or A.DPRNo like '%' +@SearchString+ '%' or A.DPRKey like '%' + @SearchString+ '%' or 
									A.DPRDate like '%' + @SearchString+ '%' or 	A.PONo like '%' + @SearchString+ '%' or  
									A.POType like '%' + @SearchString+ '%' or A.PartNo like '%' + @SearchString+ '%' or 
									A.ItemDescription like '%' +@SearchString+ '%' or A.ProdEmployee like '%' + @SearchString+ '%' or
									A.Operation like '%' +@SearchString+ '%' or A.ShiftName like '%' + @SearchString+ '%' or 
									A.ProdQty like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetEditProdDtls'
BEGIN
        Select top  1 D.DPRId, D.RouteEntryId,D.RoutLineNo,D.StartTime, D.EndTime,F.SetupFrom,F.SetupTo,F.QCFrom,F.QCTo,
		cast(D.RoutLineNo as varchar)+'-'+O.OperationName as Operation
		 from DPREntry D
		inner join FirstPieceInspectionMain F on F.FirstPieceInspId=D.FirstPieceInspId and F.IsActive=1 
		inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
		where D.IsActive=1 and D.POType=@POType and D.PrePoId=@PrePOId and D.ItemId=@ItemId
		order by D.DPRId desc
END
ELSE IF @Action='UpdateDPR'
BEGIN
     UPDATE DPRENTRY SET StartTime=@StartTime, EndTime=@EndTime
	 where DPRId=@DPRID and IsActive=1 
	 Select 1
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[EmployeeSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[EmployeeSP]
						   (
						   @Action varchar(75)=null,
						   @EmpId int =0,
						   @EmpCode varchar(20)=null,
						   @EmpName varchar(100)=null,
						   @MobileNo varchar(20)=null,
						   @Address varchar(300)=null,
						   @CountryId int =0,
						   @StateId int =0,
						   @CityId int =0,
						   @Pincode varchar(20)=null,
						   @DailyWages varchar(20)=null,
						   @WagesPerHr varchar(20)=null,
						   @UserName varchar(20)=null,
						   @Password varchar(20)=null,
						   @RoleId int =0,
						   @EmailId varchar(75)=null,
						   @DOJ varchar(20)=null,
						   @DOB varchar(20)=null,
						   @BankName varchar(75)=null,
						   @BankAccNo varchar(50)=null,
						   @IFSCCode varchar(50)=null,
						   @AadharNo varchar(30)=null,
						   @PANNo varchar(30)=null,
						   @CreatedBy int =0
						   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertEmployee'
BEGIN
   IF @EmpId=0
   BEGIN
        SET @EmpId=ISNULL((SELECT TOP 1 EmpId+1 from EmployeeDetails order by EmpId desc),1);
   END
   ELSE
   BEGIN
        UPDATE EmployeeDetails SET IsActive=0 WHERE EmpId=@EmpId;
   END     
	  INSERT INTO [dbo].[EmployeeDetails]
							   (
							    [EmpId]
							   ,[EmpCode]
							   ,[EmpName]
							   ,[MobileNo]
							   ,[Address]
							   ,[CountryId]
							   ,[StateId]
							   ,[CityId]
							   ,[Pincode]
							   ,[DailyWages]
							   ,[WagesPerHr]
							   ,[UserName]
							   ,[Password]
							   ,[RoleId]
							   ,[EmailId]
							   ,[DOJ]
							   ,[DOB]
							   ,[BankName]
							   ,[BankAccNo]
							   ,[IFSCCode]
							   ,[AadharNo]
							   ,[PANNo]
							   ,[CreatedBy]
							  )
					VALUES
					           (
							   @EmpId,
							   @EmpCode,
							   @EmpName,
							   @MobileNo,
							   @Address,
							   @CountryId,
							   @StateId,
							   @CityId,
							   @Pincode,
							   @DailyWages,
							   @WagesPerHr,
							   @UserName,
							   @Password,
							   @RoleId,
							   @EmailId,
							   @DOJ,
							   @DOB,
							   @BankName,
							   @BankAccNo,
							   @IFSCCode,
							   @AadharNo,
							   @PANNo,
							   @CreatedBy
							   )
				SELECT '1'
END
ELSE IF @Action='GetEmployeeDtls'
BEGIN
     SELECT E.EmpId,E.EmpCode, E.EmpName,E.MobileNo,E.EmailId FROM EmployeeDetails E
	 WHERE E.IsActive=1 ORDER BY E.EmpId desc
END
ELSE IF @Action='GetEmpDtlsById'
BEGIN
     SELECT E.EmpCode,E.EmpName,E.MobileNo,E.Address,E.CountryId,E.StateId,E.CityId,E.Pincode,E.DailyWages,E.WagesPerHr,E.UserName,
	 E.Password,E.RoleId,	 E.EmailId,E.DOJ,E.DOB,E.BankName,E.BankAccNo,E.IFSCCode,E.AadharNo,E.PANNo
	 FROM EmployeeDetails E
	 WHERE E.IsActive=1 and E.EmpId=@EmpId;
END
ELSE IF @Action='GetEmpDtlsForValidation'
BEGIN
   SELECT E.EmpId,E.EmpCode,E.UserName FROM EmployeeDetails E
   WHERE E.IsActive=1 
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[FinalInspectionSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FinalInspectionSP]
								 (
								 @Action varchar(75)=null,
								 @FinalInspectionId int =0,
								 @POType varchar(20)=null,
								 @PrePOId int =0,
								 @ItemId int =0,
								 @InspectionDate varchar(20)=null,
								 @InspectFrom varchar(20)=null,
								 @InspectTo varchar(20)=null,
								 @PreparedBy int =0,
								 @Reason varchar(max)=null,
								 @Attachments varchar(max)=null,
								 @Head1 varchar(50)=null,
								 @Head2 varchar(50)=null,
								 @Head3 varchar(50)=null,
								 @Head4 varchar(50)=null,
								 @Head5 varchar(50)=null,
								 @Head6 varchar(50)=null,
								 @QCStatus varchar(20)=null,
								 @CreatedBy int =0,
								 @FinalInspectionSub FinalInspectionSub READONLY
								 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertFinalInspection'
BEGIN
     SET @FinalInspectionId=ISNULL((SELECT TOP 1  FinalInspectionId+1 FROM FinalInspectionMain ORDER BY FinalInspectionId DESC),1);
	 INSERT INTO FinalInspectionMain
									(
									FinalInspectionId,
									POType,
									PrePOId,
									ItemId,
									InspectionDate,
									InspectFrom,
									InspectTo,
									PreparedBy,
									Reason,
									Attachments,
									Head1,
									Head2,
									Head3,
									Head4,
									Head5,
									Head6,
									QCStatus,
									CreatedBy
									)
						 VALUES
								   (
									@FinalInspectionId,
									@POType,
									@PrePOId,
									@ItemId,
									@InspectionDate,
									@InspectFrom,
									@InspectTo,
									@PreparedBy,
									@Reason,
									@Attachments,
									@Head1,
									@Head2,
									@Head3,
									@Head4,
									@Head5,
									@Head6,
									@QCStatus,
									@CreatedBy
									)
       INSERT INTO FinalInspectionSub
									(
									FinalInspectionId,
									Parameter,
									Specification,
									Instrument,
									ToolSetting,
									Value1,
									Value2,
									Value3,
									Value4,
									Value5,
									Value6,
									CreatedBy
									)
						SELECT     
									@FinalInspectionId,
									Parameter,
									Specification,
									Instrument,
									ToolSetting,
									Value1,
									Value2,
									Value3,
									Value4,
									Value5,
									Value6,
									@CreatedBy FROM @FinalInspectionSub;
				SELECT '1'

END
ELSE IF @Action='GetPendingFinalInspDtls'
BEGIN
       Select A.PrePOId,A.ItemId,A.PrePONo,  A.PartNo, A.Description, A.POQty, A.AccQty,'CustomerPO' as POType  from (
			Select PM.PrePONo, PS.prePoId,PS.ItemId,I.PartNo, I.Description ,PS.Qty as POQty,
			RC.RoutLineNo, (MAX(RC.RoutLineNo) OVER (PARTITION BY RC.RouteEntryId)) AS MRoutLineNo,
			PO.AccQty
			 from PrePOSub PS
			 left join FinalInspectionMain FM on FM.POType='CustomerPO' and  FM.PrePOId=PS.PrePOId and FM.ItemId=PS.ItemId and FM.IsActive=1 
			inner join RouteCardEntry RC on RC.PrePOId=PS.PrePOId and RC.ItemId =PS.ItemId and RC.IsActive=1
			inner join PrePOMain PM on PM.prePoId=PS.prePoId and PM.isActive=1
			inner join ItemMaster I on I.ItemId=PS.ItemId and I.IsActive=1
			inner join POProcessQtyDetails PO on PO.RouteEntryId=RC.RouteEntryId and PO.RoutLineNo=RC.RoutLineNo and PO.IsActive=1
			where PS.IsActive=1 and PS.Status='Closed' AND (@POType IS NULL OR @POType='CustomerPO') AND @PrePOId IN (0,PS.PrePOId) AND @ItemId in (0,PS.ItemId)
			and FM.FinalInspectionId is null
		) A where A.RoutLineNo=A.MRoutLineNo
		UNION ALL 
		 Select A.JobOrderPOId as PrePOId,A.JobOrderPOSubId as ItemId,A.PONo as PrePONo,  A.PartNo, A.Description, A.POQty, A.AccQty,'JobOrderPO' as POType from (
			Select JM.PONo, JS.JobOrderPOId,JS.JobOrderPOSubId,JS.PartNo,JS.ItemName as Description,JS.Qty as POQty,
			RC.RoutLineNo, (MAX(RC.RoutLineNo) OVER (PARTITION BY RC.RouteEntryId)) AS MRoutLineNo,
			PO.AccQty
			 from JobOrderPOSub JS
			left join FinalInspectionMain FM on FM.POType='CustomerPO' and  FM.PrePOId=JS.JobOrderPOId and FM.ItemId=JS.JobOrderPOSubId and FM.IsActive=1 
		   inner join RouteCardEntry RC on RC.PrePOId=JS.JobOrderPOId and RC.ItemId =JS.JobOrderPOSubId and RC.IsActive=1
			inner join JobOrderPOMain JM on JM.JobOrderPOId=JS.JobOrderPOId and JM.isActive=1
			inner join POProcessQtyDetails PO on PO.RouteEntryId=RC.RouteEntryId and PO.RoutLineNo=RC.RoutLineNo and PO.IsActive=1
			where JS.IsActive=1 and JS.Status='Closed' AND (@POType IS NULL OR @POType='JobOrderPO') AND @PrePOId IN (0,JS.JobOrderPOId) AND @ItemId in (0,JS.JobOrderPOSubId)
			and FM.FinalInspectionId is null
			) A where A.RoutLineNo=A.MRoutLineNo
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[FreightSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FreightSP]
                         (
						 @Action varchar(50)=null,
						 @FreightId int =0,
						 @FreightName varchar(50)=null,
						 @CreatedBy int=0
						 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertFreight'
BEGIN
   IF @FreightId=0
   BEGIN
      SET @FreightId =isnull((SELECT TOP 1 FreightId + 1 from FreightMaster order by FreightId desc),1)
   END
   ELSE
   BEGIN
        UPDATE FreightMaster SET IsActive=0 WHERE FreightId=@FreightId;
   END
           INSERT INTO FreightMaster
		                           (
								   FreightId,
								   FreightName,
								   CreatedBy
								   )
						VALUES
						           (
								   @FreightId,
								   @FreightName, 
								   @CreatedBy
								   )
						SELECT '1'
END
ELSE IF @Action='GetFreightDtls'
BEGIN
   SELECT FreightId , FreightName FROM FreightMaster WHERE IsActive=1 ORDER BY FreightId DESC
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[GeneralInvoiceSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GeneralInvoiceSP]
							     (
								 @Action varchar(75)=null,
								 @InvoiceId int =0,
							     @InvoiceNo Varchar(20)=null,
							     @InvoiceDate Varchar(20)=null,
							     @TransportMode Varchar(50)=null,
							     @VehicleNo Varchar(75)=null,
							     @DateTimeOfSupply Varchar(50)=null,
							     @PlaceOfSuppply Varchar(100)=null,
							     @CustomerId Varchar(20)=null,
							     @PONo Varchar(300)=null,
							     @PODate Varchar(20)=null,
							     @DCNo Varchar(300)=null,
							     @DCDate Varchar(20)=null,
							     @POAmmendmentNo Varchar(300)=null,
							     @POADate Varchar(20)=null,
							     @TotalAmt Varchar(20)=null,
							     @TaxId int =0,
							     @TaxAmt Varchar(20)=null,
							     @Packing Varchar(20)=null,
							     @CuttingCharge Varchar(20)=null,
							     @TransportCharge Varchar(20)=null,
							     @ServiceCharge Varchar(20)=null,
							     @FinalAmt Varchar(20)=null,
							     @ElectronicRefNo Varchar(300)=null,
								 @Remarks varchar(max)=null,
							     @CreatedBy int =0,
								 @GeneralInvoiceSub GeneralInvoiceSub readonly,
								 @Year VARCHAR(20)=NULL,
								 @AccountingYear varchar(20)=null,
					             @SearchString VARCHAR(200)=NULL,
								   @FirstRec INT =0,
								   @LastRec INT =0,
								   @DisplayStart INT =0,
								   @DisplayLength INT =0,
								   @Sortcol INT =0,
								   @SortDir varchar(10)=null
								 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertGeneralInvoice'
BEGIN
   IF @InvoiceId=0
   BEGIN
      SET @InvoiceId=ISNULL((select top 1 InvoiceId +1 from GeneralInvoiceMain where IsActive=1  order by InvoiceId desc ),1);
	  SET @InvoiceNo=(Select  Format +  FORMAT(cast(CurrentNumber as int),'D4') from SerialNoFormats where type='GeneralInvoice'  and year =@Year);
	  UPDATE SerialNoFormats set CurrentNumber=CurrentNumber +1 where type='GeneralInvoice'  and year=@Year
   END
   ELSE
   BEGIN
      UPDATE GeneralInvoiceMain SET IsActive=0 WHERE InvoiceId=@InvoiceId;
	  UPDATE GeneralInvoiceSub SET IsActive=0 WHERE InvoiceId=@InvoiceId;
   END
   INSERT INTO [dbo].[GeneralInvoiceMain]
						   (
						    [InvoiceId]
						   ,[InvoiceNo]
						   ,[AccountingYear]
						   ,[InvoiceDate]
						   ,[TransportMode]
						   ,[VehicleNo]
						   ,[DateTimeOfSupply]
						   ,[PlaceOfSuppply]
						   ,[CustomerId]
						   ,[PONo]
						   ,[PODate]
						   ,[DCNo]
						   ,[DCDate]
						   ,[POAmmendmentNo]
						   ,[POADate]
						   ,[TotalAmt]
						   ,[TaxId]
						   ,[TaxAmt]
						   ,[Packing]
						   ,[CuttingCharge]
						   ,[TransportCharge]
						   ,[ServiceCharge]
						   ,[FinalAmt]
						   ,[ElectronicRefNo]
						   ,[Remarks]
						   ,[CreatedBy]
						   )
				 VALUES
						   (
						    @InvoiceId
						   ,@InvoiceNo
						   ,@AccountingYear
						   ,@InvoiceDate
						   ,@TransportMode
						   ,@VehicleNo
						   ,@DateTimeOfSupply
						   ,@PlaceOfSuppply
						   ,@CustomerId
						   ,@PONo
						   ,@PODate
						   ,@DCNo
						   ,@DCDate
						   ,@POAmmendmentNo
						   ,@POADate
						   ,@TotalAmt
						   ,@TaxId
						   ,@TaxAmt
						   ,@Packing
						   ,@CuttingCharge
						   ,@TransportCharge
						   ,@ServiceCharge
						   ,@FinalAmt
						   ,@ElectronicRefNo
						   ,@Remarks
						   ,@CreatedBy
						    )
		INSERT INTO GeneralInvoiceSub
								     (
									 InvoiceId,
									 Description,
									 HSNCode,
									 Qty,
									 UOM,
									 Rate,
									 TaxableValue,
									 CreatedBy
									 )
							SELECT
									
									@InvoiceId,
									Description,
									HSNCode,
									Qty,
								    UOM,
									Rate,
									TaxableValue,
									@CreatedBy  FROM @GeneralInvoiceSub;
					SELECT '1'
END
ELSE IF @Action='GetGeneralInvoiceDtls'
BEGIN    
       set @FirstRec=@DisplayStart;
        set @LastRec=@DisplayStart+@DisplayLength;
					select * 
					from (
					select *,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.InvoiceId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.InvoiceNo  end asc,
					case when (@SortCol =1 and  @SortDir ='desc') then A.InvoiceNo end desc,
					case when (@SortCol =2 and  @SortDir ='asc')  then A.InvoiceDate  end asc,
				    case when (@SortCol =2 and  @SortDir ='desc') then A.InvoiceDate  end desc, 
				    case when (@SortCol =3 and  @SortDir ='asc')  then A.CustomerName  end asc,
					case when (@SortCol =3 and  @SortDir ='desc')  then A.CustomerName end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.FinalAmt  end asc,
					case when (@SortCol =4 and  @SortDir ='desc') then A.FinalAmt end desc
					)as RowNum from(
					Select GM.InvoiceId, GM.InvoiceNo, GM.InvoiceDate, C.CustomerName,GM.FinalAmt, 
					COUNT(*) over() as TotalCount from GeneralInvoiceMain GM
					inner join CustomerMaster C on  C.CustomerId=GM.CustomerId and C.IsActive=1 
					where GM.IsActive=1 
			 ) A
					 where (@SearchString is null or

							A.InvoiceNo like '%' +@SearchString + '%' or
							A.InvoiceDate like '%' +@SearchString+ '%' or
							A.CustomerName like '%' +@SearchString+ '%' or
							A.FinalAmt like '%' +@SearchString + '%' 
						))B
							 where  RowNum > @FirstRec and RowNum <= @LastRec
END
ELSE IF @Action='GetInvoiceDtlsById'
BEGIN
     SELECT GM.InvoiceNo,GM.InvoiceDate,  GM.TransportMode, GM.VehicleNo,GM.DateTimeOfSupply, GM.PlaceOfSuppply,
	 GM.CustomerId, GM.PONo, GM.PODate,  GM.DCNo, GM.DCDate, GM.POAmmendmentNo, GM.POADate, 
	 GM.TotalAmt, GM.TaxId, GM.TaxAmt, GM.Packing, GM.CuttingCharge, GM.TransportCharge, GM.ServiceCharge, GM.FinalAmt, 
	 GM.ElectronicRefNo, GM.Remarks,GM.AccountingYear
	 FROM GeneralInvoiceMain GM
	 WHERE GM.IsActive=1 AND GM.InvoiceId=@InvoiceId;
	 
     SELECT GS.Description,GS.HSNCode, GS.Qty,GS.UOM,GS.Rate,GS.TaxableValue  FROM GeneralInvoiceSub GS
	 WHERE GS.IsActive=1 AND GS.InvoiceId=@InvoiceId;
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH




GO
/****** Object:  StoredProcedure [dbo].[GRNSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GRNSP]
						(
						@Action varchar(75)=null,
						@GRNId int =0,
						@GRNNo varchar(20)=null,
						@SupplierId int =0,
						@RMPOIds varchar(max)=null,
						@GRNDate varchar(20)=null,
						@DCNo varchar(20)=null,
						@DCDate varchar(20)=null,
						@RefNo varchar(20)=null,
						@RefDate varchar(20)=null,
						@Remarks varchar(max)=null,
						@CreatedBy int =0,
						@GRNSub GRNSub readonly, 
						@SearchString VARCHAR(200)=NULL,
					   @FirstRec INT =0,
					   @LastRec INT =0,
					   @DisplayStart INT =0,
					   @DisplayLength INT =0,
					   @Sortcol INT =0,
					   @SortDir varchar(10)=null
						)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertGRN'
BEGIN
     IF @GrnId =0
	 BEGIN
	      SET @GrnId=isnull((select top 1 GRNId+1 from GRNMain order  by GRNId desc),1);
		  SET @GrnNo=@GrnId;
	 END
	 ELSE
	 BEGIN
	    
	   UPDATE RS SET RS.GrnBalQty = CAST(ISNULL(RS.GrnBalQty,'0') as decimal(18,3)) + cast(ISNULL(GS.RecQty,'0') as decimal(18,3))
	    from RMPOSub RS
	   INNER JOIN GRNSub GS on GS.RMPOId=RS.RMPOId and GS.RawMaterialId=RS.RawMaterialId	  
	    where RS.IsActive=1 and  GS.GrnId=@GrnId and GS.IsActive=1;

	    UPDATE GRNMain set IsActive=0 where grnId=@GrnId;
	    UPDATE GRNSub set IsActive=0 where grnId=@GrnId;
	 END
	     INSERT INTO [dbo].[GRNMain]
						   (
						   [GRNId]
						   ,[GRNNo]
						   ,[GRNDate]
						   ,[SupplierId]
						   ,[RMPOIds]
						   ,[DCNo]
						   ,[DCDate]
						   ,[RefNo]
						   ,[RefDate]
						   ,[Remarks]
						   ,[CreatedBy]
						   )
					VALUES
							(
							@GRNId,
							@GRNNo,
							@GRNDate,
							@SupplierId,
							@RMPOIds, 
							@DCNO,
							@DCDate,
							@RefNo,
							@RefDate, 
							@Remarks,
							@CreatedBy
							)
			
		INSERT INTO [dbo].[GRNSub]
				   ([GRNId]
				   ,[RMPOId]
				   ,[RawMaterialId]
				   ,[RecQty]
				   ,[CreatedBy]
				   )
			SELECT  
					@GrnId
					,[RMPOId]
				   ,[RawMaterialId]
				   ,[RecQty]
				   ,@CreatedBy from @GRNSub;

	   UPDATE RS SET RS.GrnBalQty = cast(ISNULL(RS.GrnBalQty,'0') as decimal(18,3))- cast(ISNULL(GS.RecQty,'0') as decimal(18,3))
	   from RMPOSub RS
	   INNER JOIN @GRNSub GS on GS.RMPOId=RS.RMPOId and GS.RawMaterialId=RS.RawMaterialId	  
	   where RS.IsActive=1 
		SELECT '1'

END 
ELSE IF @Action='GetRMPOMainDtlsForGRN'
BEGIN
   SET @RMPOIds =isnull((SELECT TOP 1 RMPOIds FROM GRNMain where IsActive=1 and GRNId=@GRNId),'');
    Select  RM.RMPOId, RM.RMPONo from RMPOMain RM
	inner join RMPOSub RS on RS.RMPOId = RM.RMPOId and RS.IsActive=1  
	and (RS.RMPOId in (Select value from fn_split(@RMPOIds,',') where value<>'') or  cast(ISNULL(RS.GrnBalQty,'0') as decimal(18,3)) > CAST('0' AS DECIMAL) )
	where RM.IsActive=1 and RM.SupplierId=@SupplierId and RM.IsApproved=1 
	group by RM.RMPOId, RM.RMPONo ;
END
ELSE IF @Action='GetRMPOSubDtlsForGRN'
BEGIN
    Select RS.RMPOId, RM.RMPONo,RS.RawMaterialId, R.CodeNo +' - ' + R.Description as RawMaterial , R.Dimension , 
	cast(ISNULL(GS.RecQty,'0') as decimal(18,3)) + cast(ISNULL(RS.GrnBalQty,'0') as decimal(18,3)) as Qty ,
	GS.RecQty,   U.UnitName  from RMPOSub RS	
	left join GRNSub GS on GS.GRNId=@GrnId and GS.IsActive=1 and GS.RMPOId=RS.RMPOId and GS.RawMaterialId=RS.RawMaterialId
	INNER JOIN RawMaterial R ON R.RawMaterialId = RS.RawMaterialId AND R.IsActive=1
	INNER JOIN UnitMaster U ON U.UnitId = RS.UnitId AND U.IsActive=1
	inner join RMPOMain RM on RM.RMPOId=RS.RMPOId and RM.IsActive=1 
	where RS.IsActive=1 and RS.RMPOId in (Select value from fn_split(@RMPOIds,',') where value<>'') and  
	cast(ISNULL(GS.RecQty,'0') as decimal(18,3)) + cast(ISNULL(RS.GrnBalQty,'0') as decimal(18,3)) > CAST('0' AS DECIMAL) 
END
ELSE IF @Action='GetGRNDtls'
BEGIN
         set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;


        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.GrnId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.GrnNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.GrnNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.GRNDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.GRNDate	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Supplier end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.RMPONos	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.RMPONos end desc			    
                     ) as RowNum  
					 from (								
						Select GM.GrnId, GM.GRNNo, GM.GRNDate,C.CustomerName as Supplier , GM.IsInspected,
						(Select RMPONo + ',' from RMPOMain RM where RM.IsActive=1 and RM.RMPOId in (Select value from fn_split(GM.RMPOIds,',') where value <>'') for xml path('')) as RMPONos,
						COUNT(*) over() as TotalCount 
						 from GRNMain GM
						inner join CustomerMaster C on C.CustomerId=GM.SupplierId and C.IsActive=1 
						where GM.IsActive=1
						  )A where (@SearchString is null or A.GRNNo like '%' +@SearchString+ '%' or
									A.GRNDate like '%' +@SearchString+ '%' or A.Supplier like '%' +@SearchString+ '%' or
									A.RMPONos like '%' + @SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec
END
ELSE IF @Action='GetGrnMainDtlsById'
BEGIN
    SELECT GM.GrnId, GM.GrnNo ,GM.GRNDate, GM.SupplierId, GM.RMPOIds, GM.RefNo, GM.RefDate,GM.DCNo, GM.DCDate, GM.Remarks FROM GrnMain GM
	where GM.IsActive=1 and GM.GRNId=@GrnId
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[IdleReasonSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[IdleReasonSP]
                             (
							 @Action varchar(50)=null,
							 @IdleReasonId int =0,
							 @IdleReason varchar(100)=null,
							 @CreatedBy int =0
							 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertIdleReasons'
BEGIN
     IF @IdleReasonId =0
	 BEGIN
	   SET @IdleReasonId=isnull((SELECT TOP 1 IdleReasonId+1 FROM IdleReasons ORDER BY IdleReasonId desc),1)
	 END
	 ELSE
	 BEGIN
	    UPDATE IdleReasons SET isActive=0 WHERE IdleReasonId=@IdleReasonId
	 END
	    INSERT INTO IdleReasons
								(
								IdleReasonId,
								IdleReason,
								CreatedBy
								)
						VALUES
							  (
							  @IdleReasonId,
							  @IdleReason,
							  @CreatedBy 
							  )
						SELECT '1'							
END
ELSE IF @Action='GetIdleReasons'
BEGIN
     SELECT IdleReasonId, IdleReason FROM IdleReasons WHERE isActive=1 ORDER BY IdleReasonId DESC
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[IntermediateQCSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[IntermediateQCSP]
							   (
							   @Action varchar(75)=null,
							   @QCId int =0,
							   @QCNo varchar(20)=null,
							   @QCDate varchar(20)=null,
							   @POType varchar(20)=null,
							   @DPRId int =0,
							   @PrePOId int =0,
							   @ItemId int =0,
							   @RouteEntryId int =0,
							   @RoutLineNo int =0,
							   @OperationId int =0,
							   @AccQty varchar(20)=null,
							   @ReworkQty varchar(20)=null,
							   @ReworkBalQty varchar(20)=null,
							   @ReworkReasonId int=0,
							   @RejQty varchar(20)=null,
							   @RejReasonId int =0,
							   @Attachment varchar(max)=null,
							   @InspectedBy int =0,
							   @CreatedBy int =0,
							   @FinalRoutLineNo int =0,
							   @FinalProcessProdQty varchar(20)=null,
							   @FromDate VARCHAR(20)=NULL,
							   @ToDate varchar(20)=null,
		                       --Optimized Query
								@FirstRec int=0,
								@SortDir varchar(10)=null,
								@SearchString varchar(200)=null,
								@DisplayStart int=0,
								@DisplayLength int=0,
								@SortCol int=0,
								@LastRec int=0
							   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertIMQC'
BEGIN

/*
  STEP 1: INSERTING INTO INTERMEDIATE QC TABLE
  STEP 2: UPDATING INSPECTION STATUS IN  DPR THAT QC HAS COMPLETED
  STEP 3:INSERTING OR UPDATING INTO POPROCESSQTY DETAILS WITH CONVERSION FACTOR
  STEP 4:IF ALL PROCESS HAS COMPLETED THEN ADDING THIS INTO ITEM STOCK
  STEP 5:UPDATING STATUS TO CLOSED IF PRODQTY REACHED POQTY IN PREPOSUB , PREPOMAIN INCASE OF CUSTOMERPO 
         AND JOBORDERPOMAIN  AND JOBORDERPOSUB IN CASE OF JOBORDERPO 
*/

/*STEP 1: */
      SET @QCId=ISNULL((SELECT TOP 1 QCId+1 FROM IntermediateQC ORDER BY QCId DESC),1);
	  SET @QCNo=@QCId;
	  Select Top 1 @RouteEntryId=D.RouteEntryId, @RoutLineNo= D.RoutLineNo, 
				@POType=D.POType,@PrePOId=D.PrePoId,@ItemId=D.ItemId,@OperationId=D.OperationId
      from DPREntry D
	  where D.IsActive=1 and D.DPRId=@DPRId; 
	   
	  INSERT INTO [dbo].[IntermediateQC]
									   (
										[QCId]
									   ,[QCNo]
									   ,[QCDate]
									   ,[POType]
									   ,[DPRId]
									   ,[PrePOId]
									   ,[ItemId]
									   ,[RouteEntryId]
									   ,[RoutLineNo]
									   ,[OperationId]
									   ,[AccQty]
									   ,[ReworkQty]
									   ,[ReworkReasonId]
									   ,[RejQty]
									   ,[RejReasonId]
									   ,[Attachment]
									   ,[InspectedBy]
									   ,[CreatedBy]
									   )
								VALUES
									    (
										@QCId,
										@QCNo,
										@QCDate,
										@POType,
										@DPRId,
										@PrePOId,
										@ItemId,
										@RouteEntryId,
										@RoutLineNo,
										@OperationId,										
								        cast(isnull(@AccQty ,'0') as float),
										cast(isnull(@ReworkQty ,'0') as float), 
										@ReworkReasonId,
								        cast(isnull(@RejQty ,'0') as float),
										@RejReasonId,
										@Attachment,
										@InspectedBy,
										@CreatedBy
										)
/*STEP 2: */
	 UPDATE DPREntry Set InspectionStatus='true' where DPRId=@DPRId;
/*STEP 3: */
	IF NOT EXISTS(SELECT TOP 1 RouteEntryId  FROM POProcessQtyDetails WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RoutLineNo  AND IsActive=1)
	BEGIN
		 INSERT INTO POProcessQtyDetails
									(
									POType,
									PrePOId,
									ItemId,
									RouteEntryId,
									RoutLineNo,
									TotalAccQty,
									AccQty,
									ReworkQty,
									RejQty,
									CreatedBy
									)
						 VALUES
								  (
								  @POType,
								  @PrePOId,
								  @ItemId,
								  @RouteEntryId,
								  @RoutLineNo,
								  cast(isnull(@AccQty ,'0') as float),
								  cast(isnull(@AccQty ,'0') as float),
								  cast(isnull(@ReworkQty ,'0') as float), 
								   cast(isnull(@RejQty ,'0') as float),
								  @CreatedBy
								  )
    END
    ELSE
    BEGIN 
       UPDATE POProcessQtyDetails SET AccQty=CAST(ISNULL(AccQty,'0')  AS FLOAT) + cast(isnull(@AccQty ,'0') as float),
									  TotalAccQty=CAST(ISNULL(TotalAccQty,'0')  AS FLOAT) + cast(isnull(@AccQty ,'0') as float),
									  ReworkQty=CAST(ISNULL(ReworkQty,'0')  AS FLOAT) + cast(isnull(@ReworkQty ,'0') as float),
									  RejQty=CAST(ISNULL(RejQty,'0')  AS FLOAT) + cast(isnull(@RejQty ,'0') as float)
	   WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RoutLineNo AND IsActive=1 
      
    END
/*STEP 4 & 5: */
	SET @FinalRoutLineNo =(SELECT TOP 1 RoutLineNo FROM RouteCardEntry R where R.IsActive=1 and RouteEntryId=@RouteEntryId order by RoutLineNo desc);
	set @FinalProcessProdQty=(SELECT TOP 1 AccQty FROM POProcessQtyDetails P WHERE P.IsActive=1 AND P.RouteEntryId=@RouteEntryId AND RoutLineNo=@FinalRoutLineNo);
	IF @POType='CustomerPO'
	BEGIN
	    UPDATE PrePOSub  SET Status='Closed' , ClosedOn=getDate()
		WHERE PrePOId=@PrePOId and ItemId=@ItemId AND ISACTIVE=1  and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE PM  SET Status='Closed' , ClosedOn=getDate() 
		FROM PrePOMain PM
		INNER JOIN (
				SELECT 	COUNT(CASE when PS.Status='Closed' then 1 else null end ) as ClosedCount, Count(PS.ItemId) as TotalCount
				FROM PrePOSub PS
				WHERE PS.IsActive=1 and PS.PrePOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount 
	     IF @RoutLineNo=@FinalRoutLineNo
		 BEGIN
		      IF EXISTS(SELECT TOP 1 ItemId FROM ItemStock WHERE ItemId=@ItemId and IsActive=1 )
			  BEGIN
			     UPDATE ItemStock SET Qty = CAST(ISNULL(QTY,'0') AS decimal(18,2)) + cast(isnull(@AccQty ,'0') as float) 
				 WHERE ItemId=@ItemId and IsActive=1 
			  END
			  ELSE
			  BEGIN
				   INSERT INTO ItemStock
									(
									ItemId,
									Qty,
									CreatedBy
									)
						VALUES
								  (
								  @ItemId,
								  cast(isnull(@AccQty ,'0') as float),
								  @CreatedBy
								  )
			      
			  END
		 END
	END
	ELSE
	BEGIN
	    UPDATE JobOrderPOSub  SET Status='Closed' , ClosedOn=getDate()
		WHERE JobOrderPOId=@PrePOId and JobOrderPOSubId=@ItemId AND ISACTIVE=1  and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE JM  SET Status='Closed' , ClosedOn=getDate() 
		FROM JobOrderPOMain JM
		INNER JOIN (
				SELECT 	COUNT(CASE when JS.Status='Closed' then 1 else null end ) as ClosedCount, Count(JS.JobOrderPOSubId) as TotalCount
				FROM JobOrderPOSub JS
				WHERE JS.IsActive=1 and JS.JobOrderPOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount  
	END
/*STEP 4 & 5 ENDS */
						SELECT '1'
END
ELSE IF @Action='GetPendingIMQCDtls'
BEGIN
        Select D.DPRId, D.DPRDate,E.EmpName as ProdEmployee,S.ShiftName,
		ISNULL(PM.PrePONo,JM.PONo) as PrePONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
		M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
		D.RouteEntryId as RouteCardNo,D.RoutLineNo, O.OperationCode +' - ' + O.OperationName as Operation,
		isnull(PS.Qty,JS.Qty) as POQty, D.Qty as ProdQty, 		
		case when D.Rework='true' or  RC.ConvFact is null or RC.ConvFact='' then 1 else RC.ConvFact end as ConvFact
		from DPREntry D
		inner join RouteCardEntry RC on RC.RouteentryId=D.RouteEntryId and RC.RoutLineNo=D.RoutLineNo and RC.IsActive=1 
		inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 
		left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
		left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
		left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
		left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
		left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1
		inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1  
		inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
		inner join ShiftMaster S on S.ShiftId=D.ShiftId and S.IsActive=1 
		where D.isActive=1 and D.DPRKey in ('Production','DirectProduction') and D.ContinueShift='false' and D.InspectionStatus='false'
	          and CAST(D.DPRDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
END
ELSE IF @Action='GetIMQCDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.QCID end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.QCNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.QCNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.QCDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.QCDate end desc,	
			                 case when (@SortCol =3 and  @SortDir ='asc')  then A.DPRDate	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.DPRDate	end desc ,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.EmpName	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.EmpName	end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.ShiftName	end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.ShiftName	end desc,
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.PONo	end desc,
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.RoutCardNo end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.RoutCardNo end desc,	
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.ItemDescription end desc,
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.POQty end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.POQty end desc,	
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.ProcessQty end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.ProcessQty end desc,	
							 case when (@SortCol =12 and  @SortDir ='asc')  then A.ProdQty end asc,
							 case when (@SortCol =12 and  @SortDir ='desc') then A.ProdQty end desc,
							 case when (@SortCol =13 and  @SortDir ='asc')  then A.Accqty end asc,
							 case when (@SortCol =13 and  @SortDir ='desc') then A.Accqty end desc,	
							 case when (@SortCol =14 and  @SortDir ='asc')  then A.ReworkQty end asc,
							 case when (@SortCol =14 and  @SortDir ='desc') then A.ReworkQty end desc,
							 case when (@SortCol =15 and  @SortDir ='asc')  then A.ReworkReason end asc,
							 case when (@SortCol =15 and  @SortDir ='desc') then A.ReworkReason end desc,	
							 case when (@SortCol =16 and  @SortDir ='asc')  then A.Rejqty end asc,
							 case when (@SortCol =16 and  @SortDir ='desc') then A.Rejqty end desc,	
							 case when (@SortCol =17 and  @SortDir ='asc')  then A.RejReason end asc,
							 case when (@SortCol =17 and  @SortDir ='desc') then A.RejReason end desc,
							 case when (@SortCol =18 and  @SortDir ='asc')  then A.InspectedBy end asc,
							 case when (@SortCol =18 and  @SortDir ='desc') then A.InspectedBy end desc
                     ) as RowNum  
					 from (	
							    Select  IQ.QCID,IQ.QCNo,IQ.QCDate,Iq.Attachment, D.DPRDate,E.EmpName,S.ShiftName,
								ISNULL(PM.PrePONo,JM.PONo) as PONo,
								RC.RoutCardNo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
								isnull(PS.Qty,JS.Qty) as POQty,RC.ProcessQty, D.Qty as ProdQty,
								IQ.Accqty,IQ.ReworkQty, RW.Rework as ReworkReason,  IQ.Rejqty,RJ.Rejection as RejReason,
								IE.EmpName as InspectedBy,Count(*) OVER() as TotalCount
								from IntermediateQC IQ
								inner join EmployeeDetails IE on IE.EmpId=IQ.InspectedBy and IE.IsActive =1 
								inner join DPREntry D on D.DPRId=IQ.DPRId and D.IsActive=1 
								inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
								inner join ShiftMaster S on S.ShiftId=D.ShiftId and S.IsActive=1 
								left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
								left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
								left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
								left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
								left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1
								inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1  
								inner join RouteCardEntry RC on RC.RouteEntryId=D.RouteEntryId and RC.RoutLineNo=D.RoutLineNo and RC.IsActive=1 
								left join RejectionReason RJ on RJ.RejectionReasonId=IQ.RejReasonId and RJ.IsActive=1 
								left join ReworkReason RW on RW.ReworkReasonId=IQ.ReworkReasonId and RW.IsActive=1 
								where IQ.IsActive=1 and IQ.POType=@POType
					    )A where (@SearchString is null  or A.QCNo like '%' +@SearchString+ '%' or A.QCDate like '%' + @SearchString+ '%' or 
									A.DPRDate like '%' + @SearchString+ '%' or 	A.EmpName like '%' + @SearchString+ '%' or 
									A.ShiftName like '%' + @SearchString+ '%' or  	A.PONo like '%' + @SearchString+ '%' or 
									A.RoutCardNo like '%' + @SearchString+ '%' or A.PartNo like '%' +@SearchString+ '%' or
									A.ItemDescription like '%' + @SearchString+ '%' or A.POQty like '%' +@SearchString+ '%' or
									A.ProcessQty like '%' + @SearchString+ '%' or A.ProdQty like '%' +@SearchString+ '%' or 
									A.Accqty like '%' + @SearchString+ '%' or A.ReworkQty like '%' +@SearchString+ '%' or 
									A.ReworkReason like '%' + @SearchString+ '%' or A.Rejqty like '%' +@SearchString+ '%' or
									A.RejReason like '%' + @SearchString+ '%' or A.InspectedBy like '%' + @SearchString+ '%'
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[InvoiceSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[InvoiceSP]
						   (
						   @Action varchar(75)=null,
						   @POType varchar(20)=null,
						   @CustomerId int =0,
						   @InvoiceSub InvoiceSub READONLY,
						   @InvoiceId INT=0,
						   @InvoiceNo varchar(20)=null,
						   @InvoiceDate varchar(20)=null,
						   @TermsId int =0,
						   @PaymentTermsId int =0,
						   @PreCarriageBy varchar(50)=null,
						   @PlaceOfReceipt varchar(75)=null,
						   @FlightNo varchar(75)=null,
						   @PortOfLoading varchar(75)=null,
						   @PortOfDischarge varchar(75)=null,
						   @FinalDestination varchar(75)=null,
						   @OriginCountry varchar(75)=null,
						   @DestinationCountry varchar(75)=null,
						   @Terms_ConditionsDtls varchar(max)=null,
						   @NetAmt varchar(20)=null,
						   @FreightAmt varchar(20)=null,
						   @GrossAmt varchar(20)=null,
						   @CreatedBy int =0,						   
						   @SearchString VARCHAR(200)=NULL,
						   @FirstRec INT =0,
						   @LastRec INT =0,
						   @DisplayStart INT =0,
						   @DisplayLength INT =0,
						   @Sortcol INT =0,
						   @SortDir varchar(10)=null
						   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='GetInvoiceItemDtls'
BEGIN
  IF @POType='CustomerPO'
  BEGIN
        Select PM.PrePOId,PS.ItemId,PM.PrePONo,I.PartNo, I.Description,PS.InvoiceBalqty,RP.Weight from PrePOSub PS
		inner join PrePOMain PM on PM.PrePOId = PS.PrePOId and PM.IsActive=1 and PM.CustId=@CustomerId
		inner join ItemMaster I on I.ItemId=PS.ItemId and I.IsActive=1 
		inner join RMPlanning RP on RP.prePoId = PS.prePoId and RP.itemId=PS.ItemId and RP.IsActive=1
		where PS.IsActive=1 and PS.Status='Closed' and PS.DeliveryStatus='No' AND CAST(ISNULL(PS.InvoiceBalQty,'0') as decimal) > cast('0' as decimal)
  END
  ELSE
  BEGIN
      	Select JS.JobOrderPOId as PrePOId, JS.JobOrderPOSubId as ItemId,JM.PONo as PrePONo, JS.PartNo,JS.ItemName as Description, JS.InvoiceBalQty,'' as Weight from JobOrderPOSub JS
		inner join JobOrderPOMain JM on JM.JobOrderPOId=JS.JobOrderPOId and JM.IsActive=1 and JM.CustomerId=@CustomerId
		where JS.IsActive=1 and JS.Status='Closed' and JS.DeliveryStatus='No' AND CAST(ISNULL(JS.InvoiceBalQty,'0') as decimal) > cast('0' as decimal)
  END
END
ELSE IF @Action='InsertInvoice'
BEGIN
     SET @InvoiceId=isnull((SELECT TOP 1 InvoiceId+1 FROM InvoiceMain ORDER BY InvoiceId desc),1);
	 SET @InvoiceNo=@InvoiceId;
	 INSERT INTO InvoiceMain
							(
							InvoiceId,
							InvoiceNo,
							InvoiceDate,
							POType,
							CustomerId,
							TermsId,
							PaymentTermsId,
							PreCarriageBy,
							PlaceOfReceipt,
							FlightNo,
							PortOfLoading,
							PortOfDischarge,
							FinalDestination,
							OriginCountry,
							DestinationCountry,
							Terms_ConditionsDtls,
							NetAmt,
							FreightAmt,
							GrossAmt,
							CreatedBy
							)
				VALUES
				          (
							@InvoiceId,
							@InvoiceNo,
							@InvoiceDate,
							@POType,
							@CustomerId,
							@TermsId,
							@PaymentTermsId,
							@PreCarriageBy,
							@PlaceOfReceipt,
							@FlightNo,
							@PortOfLoading,
							@PortOfDischarge,
							@FinalDestination,
							@OriginCountry,
							@DestinationCountry,
							@Terms_ConditionsDtls,
							@NetAmt,
							@FreightAmt,
							@GrossAmt,
							@CreatedBy
						  )
	    INSERT INTO InvoiceSub
							  (
							   InvoiceId,
							   POType,
							   PrePOId,
							   ItemId,
							   Qty,
							   UnitWeight,
							   OverallWeight,
							   UnitPrice,
							   TotalPrice,
							   CreatedBy
							   )
					  SELECT  @InvoiceId,
							  @POType,
							  PrePOId,
							  ItemId,
							  Qty,
							  UnitWeight,
							  OverallWeight,
							  UnitPrice,
							  TotalPrice,
							  @CreatedBy from @InvoiceSub;
		IF @POType='CustomerPO'
		BEGIN
		     UPDATE PS SET InvoiceBalQty=CAST(ISNULL(PS.InvoiceBalQty,'0') as decimal) - CAST(ISNULL(T.Qty,'0') as decimal),
						   DeliveryStatus=CASE WHEN CAST(ISNULL(PS.InvoiceBalQty,'0') as decimal) - CAST(ISNULL(T.Qty,'0') as decimal) = CAST('0' AS decimal) THEN 'Yes' else 'No' end
			 FROM PrePOSub PS 
			 inner join @InvoiceSub T on T.PrePOId=PS.PrePOId and T.ItemId=PS.ItemId 
			 where PS.IsActive=1 ;

			 Update I SET I.Qty=CAST(ISNULL(I.Qty,'0') as decimal) - CAST(ISNULL(T.Qty,'0') as decimal)
			 FROM ItemStock I 
			 inner join 
				 (
				  SELECT T.ItemId, sum(CAST(ISNULL(T.Qty,'0') as decimal)) as Qty FROM @InvoiceSub T GROUP BY T.ItemId 
				 ) T ON T.ItemId=I.ItemId
			 WHERE I.IsActive=1 
		END
		ELSE
		BEGIN
		     UPDATE JS SET InvoiceBalQty=CAST(ISNULL(JS.InvoiceBalQty,'0') as decimal) - CAST(ISNULL(T.Qty,'0') as decimal),
						   DeliveryStatus=CASE WHEN CAST(ISNULL(JS.InvoiceBalQty,'0') as decimal) - CAST(ISNULL(T.Qty,'0') as decimal) = CAST('0' AS decimal) THEN 'Yes' else 'No' end
			 FROM JobOrderPOSub JS 
			 inner join @InvoiceSub T on T.PrePOId=JS.JobOrderPOId and T.ItemId=JS.JobOrderPOSubId 
			 where JS.IsActive=1 ;
		END
			SELECT '1'

END
ELSE IF @Action='GetInvoiceDtls'
BEGIN
        Set @FirstRec=@DisplayStart;
        Set @LastRec=@DisplayStart+@DisplayLength;

        Select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.InvoiceId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.InvoiceNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.InvoiceNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.InvoiceDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.InvoiceDate	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.CustomerName end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.CustomerName end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.GrossAmt	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.GrossAmt end desc		    
                     ) as RowNum  
					 from (	
					    SELECT IM.InvoiceId,IM.InvoiceNo,IM.InvoiceDate,C.CustomerName, IM.GrossAmt,COUNT(*) over() as TotalCount 
					    FROM InvoiceMain IM
						INNER JOIN CustomerMaster C ON C.CustomerId=IM.CustomerId AND C.IsActive=1 
						WHERE IM.IsActive=1 and IM.POType=@POType
					 )A where (@SearchString is null or A.InvoiceNo like '%' +@SearchString+ '%' or
									A.InvoiceDate like '%' +@SearchString+ '%' or A.CustomerName like '%' +@SearchString+ '%' or
									A.GrossAmt like '%' + @SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetInvoiceDtlsById'
BEGIN
    SELECT IM.InvoiceNo,IM.InvoiceDate,IM.CustomerId,IM.TermsId,IM.PaymentTermsId,IM.PreCarriageBy,IM.PlaceOfReceipt,
	IM.FlightNo,IM.PortOfLoading,IM.PortOfDischarge,IM.FinalDestination,IM.OriginCountry,IM.DestinationCountry,IM.Terms_ConditionsDtls,IM.NetAmt,
	IM.FreightAmt,IM.GrossAmt
	 FROM InvoiceMain IM
	WHERE IM.IsActive=1 and IM.InvoiceId=@InvoiceId;

	IF @POType='CustomerPO'
	BEGIN
		Select  PM.PrePOId,S.ItemId,PM.PrePONo,I.PartNo, I.Description,S.Qty,S.UnitPrice,S.TotalPrice from InvoiceSub S
		inner join PrePOMain PM on PM.PrePOId = S.PrePOId and PM.IsActive=1
		inner join ItemMaster I on I.ItemId=S.ItemId and I.IsActive=1 
		WHERE S.IsActive=1 AND S.InvoiceId=@InvoiceId;
	END
	ELSE
	BEGIN
	    Select  JS.JobOrderPOId as PrePOId, JS.JobOrderPOSubId as ItemId,JM.PONo as PrePONo, JS.PartNo,JS.ItemName as Description,S.Qty,S.UnitPrice,S.TotalPrice from InvoiceSub S
		inner join JobOrderPOMain JM on JM.JobOrderPOId=S.PrePOId and JM.IsActive=1
		inner join JobOrderPOSub JS on S.PrePOId=JS.JobOrderPOId and JS.JobOrderPOSubId=S.ItemId and JS.IsActive=1 
		WHERE S.IsActive=1 AND S.InvoiceId=@InvoiceId;
	END
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[InwardDCSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[InwardDCSP]
						  (
						  @Action varchar(75)=null,
						  @InwardDCId int =0,
						  @DCId INT =0,
						  @POType varchar(20)=null,
						  @VendorId int =0,
						  @InwardDCNo varchar(20)=null,
						  @InwardDCDate varchar(20)=null,
					      @VendorDCNo varchar(20)=null,
						  @VendorDDate varchar(20)=null,
						  @CreatedBy int =0,
						  @InWardDCSub InWardDCSub READONLY,
						  @InwardEndBitStk InwardEndBitStk readonly,
						  @SearchString VARCHAR(200)=NULL,
						  @FirstRec INT =0,
						  @LastRec INT =0,
						  @DisplayStart INT =0,
						  @DisplayLength INT =0,
						  @Sortcol INT =0,
						  @SortDir varchar(10)=null
						  )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action ='InsertInwardDcEntry'
BEGIN
  IF @InwardDCId=0
   BEGIN
      SET @InwardDCId= ISNULL((select top 1 InwardDCId +1 from InwardDCMain   order by InwardDCId desc ),1);
	  SET @InwardDCNo= @InwardDCId;
   END
   ELSE
   BEGIN
   --Reducing EndBit Stock From  RM Mid Stock Begins
       Select * into #OMidStk from (
				Select T.RawMaterialId ,T.OperationId,  T.Text1 , T.Text2, T.Text3, T.Value1, T.Value2, T.Value3,
				SUM(cast(ISNULL(T.Qty,'0') as decimal(18,2))) as Qty
				 from InwardEndBitStk  T 
				 where T.IsActive=1 and T.InwardId = @InwardDCId
		         group by  T.RawMaterialId ,T.OperationId,  T.Text1 , T.Text2, T.Text3, T.Value1, T.Value2, T.Value3
			 )A;
     Update RM  Set RM.Qty =cast(ISNULL(RM.Qty,'0') as decimal(18,2)) - cast(ISNULL(T.Qty,'0') as decimal(18,2))
     from RMMidStock RM
     inner join #OMidStk T on RM.RawMaterialId=T.RawMaterialId and RM.OperationId = T.OperationId and 
								   RM.Text1=T.Text1 and RM.Text2=T.Text2 and RM.Text3=T.Text3 
								   and RM.Value1=T.Value1 and RM.Value2=T.Value2 and RM.Value3=T.Value3
   --Reducing EndBit Stock From  RM Mid Stock Ends

	 Update DS Set DS.InwardBalQty =CAST(ISNULL(DS.InwardBalQty,'0') as decimal(18,2)) + CAST(ISNULL(ID.InwardDCQty,'0') as decimal(18,2))
	  +CAST(ISNULL(ID.ReworkQty,'0') as decimal(18,2))+CAST(ISNULL(ID.RejectionQty,'0') as decimal(18,2))
	 from DCEntrySub DS 
	 inner join InwardDCSub ID on ID.RouteEntryId=DS.RouteEntryId and ID.RoutLineNo=DS.RoutLineNo  and ID.IsActive=1 
	 where DS.IsActive=1 and  ID.InwardId=@InwardDCId and  DS.DCId=ID.DCId;

      UPDATE InwardDCMain SET isActive=0 WHERE InwardDCId=@InwardDCId;
      UPDATE InwardDCSub SET isActive=0 WHERE InwardId=@InwardDCId;
      UPDATE InwardEndBitStk SET isActive=0 WHERE InwardId=@InwardDCId;
   END
     INSERT INTO [dbo].[InwardDCMain]
							   (
							    InwardDCId
							   ,InwardDCNo
							   ,InwardDCDate
							   ,POType
							   ,VendorId
							   ,DCId
							   ,VendorDCNo
							   ,VendorDCDate
							   ,CreatedBy
							   )
					VALUES
						    (
							    @InwardDCId
							   ,@InwardDCNo
							   ,@InwardDCDate
							   ,@POType
							   ,@VendorId
							   ,@DCId
							   ,@VendorDCNo
							   ,@VendorDDate
							   ,@CreatedBy
							) 
	 INSERT INTO InwardDCSub
										(
										InWardID,
										DCId,
										PrePOId,
										ItemId,
										RawMaterialId,
										RouteEntryId,
										RoutLineNo,
										OperationId,
										InwardDCQty,
										ReworkQty,
										RejectionQty,
										CreatedBy
										)
								SELECT @InwardDCId,
									   @DCId,
								        PrePOId,
										ItemId,
										RawMaterialId,
										RouteEntryId,
										RoutLineNo,
										OperationId,
										InwardDCQty,
										ReworkQty,
										RejectionQty,
										@CreatedBy from @InWardDCSub;
	 Insert into InwardEndBitStk
								(
								InwardId,
								RouteEntryId,
								RoutLineNo,
								RawMaterialId,
								OperationId,
								Text1,
								Text2,
								Text3,
								Value1,
								Value2,
								Value3,
								Qty
								)
					  SELECT    @InwardDCId,
							    RouteEntryId,
							    RoutLineNo,
								RawMaterialId,
								OperationId,
								Text1,
								Text2,
								Text3,
								Value1,
								Value2,
								Value3,
								Qty FROM @InwardEndBitStk;
     
	 Update DS Set DS.InwardBalQty =CAST(ISNULL(DS.InwardBalQty,'0') as decimal(18,2)) - CAST(ISNULL(ID.InwardDCQty,'0') as decimal(18,2))
	 -CAST(ISNULL(ID.ReworkQty,'0') as decimal(18,2))-CAST(ISNULL(ID.RejectionQty,'0') as decimal(18,2))
	 from DCEntrySub DS 
	 inner join @InWardDCSub ID on ID.RouteEntryId=DS.RouteEntryId and ID.RoutLineNo=DS.RoutLineNo
	 where DS.IsActive=1 and DS.DCId=@DCId;


     --Adding Stock To  RM  Mid Stock
		 Select * into #RMMidStk from (
				Select T.RawMaterialId ,T.OperationId,  T.Text1 , T.Text2, T.Text3, T.Value1, T.Value2, T.Value3,
				SUM(cast(ISNULL(T.Qty,'0') as decimal(18,2))) as Qty
				 from @InwardEndBitStk  T
				 group by  T.RawMaterialId ,T.OperationId,  T.Text1 , T.Text2, T.Text3, T.Value1, T.Value2, T.Value3
         )A	  
		 Update RM  Set RM.Qty =cast(ISNULL(RM.Qty,'0') as decimal(18,2)) + cast(ISNULL(T.Qty,'0') as decimal(18,2))
         from RMMidStock RM
         inner join #RMMidStk T on RM.RawMaterialId=T.RawMaterialId and RM.OperationId = T.OperationId and 
								   RM.Text1=T.Text1 and RM.Text2=T.Text2 and RM.Text3=T.Text3 
								   and RM.Value1=T.Value1 and RM.Value2=T.Value2 and RM.Value3=T.Value3
         where RM.IsActive=1;
		 INSERT INTO [dbo].RMMidStock
						   (
						    [RawMaterialId]
						   ,[OperationId]
						   ,[Text1]
						   ,[Text2]
						   ,[Text3]
						   ,[Value1]
						   ,[Value2]
						   ,[Value3]
						   ,[Qty]
						   ,[CreatedBy]
		                  )
				SELECT 
						  T.RawMaterialId, 
						  T.OperationId,
						  T.Text1,
						  T.Text2,
						  T.Text3,
						  T.Value1,
						  T.Value2,
						  T.Value3,
						  T.Qty,
						  @CreatedBy  FROM #RMMidStk T 
						  where not exists(Select RawMaterialId from RMMidStock RM 
										   where RM.RawMaterialId=T.RawMaterialId and RM.OperationId = T.OperationId and 
										   RM.Text1=T.Text1 and RM.Text2=T.Text2 and RM.Text3=T.Text3
										   and RM.Value1=T.Value1 and RM.Value2=T.Value2 and RM.Value3=T.Value3 )
			SELECT '1'
END
ELSE IF @Action='GetDCMainDtlsForInward'
BEGIN
       Set @DCId =(Select top 1 DCId from InwardDCMain where InwardDCId=@InwardDCId and IsActive=1);

	   Select DM.DCId, DM.DCNo,DM.DCDate from DCEntryMain DM
	   inner join DCEntrySub DS on DS.DCId=DM.DCId and DS.IsActive=1 and (DS.DCId=@DCId or cast(ISNULL(DS.InwardBalQty,'0') as decimal(18,3)) > CAST('0' AS DECIMAL) )
	   where DM.IsActive=1 and DM.SupplierId=@VendorId AND DM.POType=@POType
       group by DM.DCId, DM.DCNo, DM.DCDate
END
ELSE IF @Action='GetDCSubDtlsForInward'
BEGIN
		SELECT DS.PrePOId, ISNULL(PM.PrePONo,JM.PONo) as PrePONo,	
		DS.ItemId, 
		case when @POType='CustomerPO' then IM.PartNo+'-'+IM.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
		DS.RawMaterialId,RM.CodeNo+'-' + RM.Description as RawMaterial,
		DS.DimensionId,RW.Text1 +'-' + RW.Value1 + case when RW.Text2 <>'' or RW.Text2 is not  null then ' * ' + RW.Text2+ '-'+RW.Value2 +' * ' else ' * ' end +RW.Text3 +'-' +RW.Value3 as Dimension,
		RM.Text1,RM.Text2,RM.Text3,RM.Value1,RM.Value2,RM.Value3,
		DS.RouteEntryId, DS.RoutLineNo, DS.OperationId, 
		cast(DS.RoutLineNo as varchar)+'-'+O.OperationName as Operation,
		DS.Qty as DCQty, cast(ISNULL(ID.InwardDCQty,'0') as decimal(18,2)) + cast(ISNULL(ID.ReworkQty,'0') as decimal(18,2))+cast(ISNULL(ID.RejectionQty,'0') as decimal(18,2)) + cast(ISNULL(DS.InwardBalQty,'0') as decimal(18,2)) as PendingQty ,
		ID.InwardDCQty , ID.ReworkQty, ID.RejectionQty	
		FROM DCEntrySub DS
		left join InwardDCSub ID on ID.InwardId=@InwardDCId and ID.IsActive=1 and ID.RouteEntryId=DS.RouteEntryId and ID.RoutLineNo=DS.RoutLineNo
		left join PrePOMain PM on @POType='CustomerPO' and  PM.PrePOId =DS.PrePOId and PM.isActive=1
		left join JobOrderPOMain JM on   @POType='JobOrderPO' and  JM.JobOrderPOId =DS.PrePOId and JM.isActive=1
		left join ItemMaster IM on @POType='CustomerPO' and IM.ItemId=DS.ItemId and IM.IsActive=1
		left join RawMaterial RM on @POType='CustomerPO' and  RM.RawMaterialId =DS.RawMaterialId and RM.IsActive=1 
		left join JobOrderPOSub JS on @POType='JobOrderPO' and JS.JobOrderPOId=DS.PrePOId and JS.JobOrderPOSubId=DS.ItemId and JS.IsActive=1 
		left join RMDimensionWiseStock RW on @POType='CustomerPO' and DS.RoutLineNo=1 and RW.RMDimensionId = DS.DimensionId and RW.IsActive=1
		inner join OperationMaster O on O.OperationId=DS.OperationId and O.IsActive=1
		WHERE DS.IsActive=1 and DS.DCId=@DCId AND  cast(ISNULL(ID.InwardDCQty,'0') as decimal(18,2)) + cast(ISNULL(DS.InwardBalQty,'0') as decimal(18,2))>CAST('0' AS decimal)
END
ELSE IF @Action='GetInwardDtls'
BEGIN
    Set @FirstRec=@DisplayStart;
    Set @LastRec=@DisplayStart+@DisplayLength;

     select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.InwardDCID end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.InwardDCNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.InwardDCNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.InwardDCDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.InwardDCDate	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.VendorName end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.VendorName end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.DCNo	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.DCNo end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.VendorDCNo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.VendorDCNo end desc	,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.VendorDCDate end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.VendorDCDate end desc			    
                     ) as RowNum  
					 from (								
						Select IM.InwardDCID, IM.InwardDCNo, IM.InwardDCDate, IM.VendorDCNo,IM.VendorDCDate, C.CustomerName as VendorName,DM.DCNo,IM.InspectStatus,
						COUNT(*) over() as TotalCount  from InwardDCMain IM
						inner join DCEntryMain DM on DM.DCId=IM.DCId and DM.IsActive=1 
						inner join CustomerMaster C on C.CustomerId = IM.VendorId and C.IsActive=1 
						where IM.IsActive=1 and IM.POType=@POType
						  )A where (@SearchString is null or A.InwardDCNo like '%' +@SearchString+ '%' or
									A.InwardDCDate like '%' +@SearchString+ '%' or A.VendorName like '%' +@SearchString+ '%' or
									A.DCNo like '%' + @SearchString+ '%' or A.VendorDCNo like '%' +@SearchString+ '%'
									or  A.VendorDCDate like '%' +@SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetInwardDtlsById'
BEGIN
   SELECT IM.InwardDCNo,IM.InwardDCDate, IM.VendorId, IM.DCId,IM.VendorDCNo, IM.VendorDCDate,DM.DCDate  FROM InwardDCMain IM
   inner join DCEntryMain DM on DM.DCId=IM.DCId and DM.IsActive=1 
   WHERE IM.IsActive=1 and IM.InwardDCId=@InwardDCId;

   Select IE.RouteEntryId, IE.RoutLineNo, IE.RawMaterialId,IE.OperationId,IE.Text1,IE.Text2,IE.Text3,IE.Value1,IE.Value2,
   IE.Value3,IE.Qty from InwardEndBitStk IE
   where IsActive=1 and IE.InwardId=@InwardDCId;
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[ItemIssueSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ItemIssueSP]
							(
							@Action varchar(75)=null,
							@IssueId int =0,
							@ItemId int =0,
							@MachineId int =0,
							@IssueQty varchar(20)=null,
							@ReturnedQty varchar(20)=null,
							@OperatorId int =0,
							@IssuedOn varchar(30)=null,
							@Remarks varchar(max)=null,
							@CreatedBy int =0,
							@ReturnId int =0,
							@ReturnedOn varchar(30)=null,
							@ReturnedBy int =0,
							@Status varchar(20)=null
							)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertItemIssue'
BEGIN
    SET @IssueId =isnull((SELECT TOP 1 IssueId+1 FROM ItemIssue order by IssueId desc),1);
	INSERT INTO ItemIssue
						(
						IssueId,
						ItemId,
						MachineId,
						IssueQty,
						ReturnedQty,
						OperatorId,
						IssuedOn,
						Remarks,
						CreatedBy
						)
				VALUES
						(
						@IssueId,
						@ItemId,
						@MachineId,
						@IssueQty,
						'0',
						@OperatorId,
						@IssuedOn,
						@Remarks,
						@CreatedBy
						)

	UPDATE ItemStock SET Qty=isnull(CAST(Qty AS float),'0') - isnull(CAST(@IssueQty as float),'0') where ItemId=@ItemId and IsActive=1 
			SELECT '1'
END
ELSE IF @Action='InsertItemReturn'
BEGIN
      SET @ReturnId =isnull((SELECT TOP 1 ReturnId+1 FROM ItemReturn order by ReturnId desc),1);
	  INSERT INTO ItemReturn
				           (
						   ReturnId,
						   IssueId,
						   ReturnedOn,
						   ReturnQty,
						   ReturnedBy,
						   Status,
						   Remarks,
						   CreatedBy
						   )
					VALUES
						(
						@ReturnId,
						@IssueId,
						@ReturnedOn,
						@ReturnedQty,
						@ReturnedBy,
						@Status,
						@Remarks,
						@CreatedBy
						)
		UPDATE ItemIssue SET ReturnedQty=ISNULL(CAST(ReturnedQty AS float),'0') + ISNULL(CAST(@ReturnedQty AS float),'0') 
		WHERE IssueId=@IssueId;
		IF @Status='Ok'
		BEGIN
		   UPDATE ItemStock SET Qty=CAST(isnull(Qty,'0') AS float)+ CAST(isnull(@ReturnedQty,'0') as float) where ItemId=@ItemId and IsActive=1 
		END
		ELSE
		BEGIN
		    IF EXISTS(SELECT TOP 1 ItemId FROM Wear_DamagedItemStock WHERE Status=@Status AND ItemId=@ItemId )
			BEGIN
			     UPDATE Wear_DamagedItemStock SET Qty=CAST(ISNULL(Qty,'0') AS DECIMAL(18,2)) +  CAST(isnull(@ReturnedQty,'0') as float)
				 WHERE  Status=@Status AND ItemId=@ItemId ;
			END
			ELSE
			BEGIN
			   INSERT INTO Wear_DamagedItemStock
												 (
												 ItemId,
												 Qty,
												 Status,
												 CreatedBy
												 )
										VALUES
											    (
												@ItemId,
												@ReturnedQty,
												@Status,
												@CreatedBy
												)
									SELECT '1'
			END
		     
		END
			SELECT '1'
END
ELSE IF @Action='GetItemIssueDtls'
BEGIN
    Select I.IssueId,IT.ItemTypeName, I.ItemId, IM.PartNo +' - '+IM.Description as PartNo_Description,M.MachineCode + ' - ' + M.MachineName as MachineCode_Name,
	E.EmpName as OperatorName, I.IssueQty,I.IssuedOn,I.ReturnedQty,ISNULL(cast(I.IssueQty as float),'0.00') - ISNULL(cast(I.ReturnedQty as float),'0.00') as BalQty
	from ItemIssue I
	inner join ItemMaster IM on IM.ItemId=I.ItemId and IM.IsActive=1 
	inner join ItemTypeMaster IT on IT.ItemTypeId=IM.ItemTypeId and IT.IsActive=1 
	inner join MachineDetails M on M.MachineId=I.MachineId and M.IsActive=1 
	inner join EmployeeDetails E on E.EmpId=I.OperatorId and E.IsActive=1 
	where I.IsActive=1 and @OperatorId in (0,I.OperatorId) and @ItemId in (0,I.ItemId) and @MachineId in (0,I.MachineId)
	ORDER BY I.IssueId DESC
END
ELSE IF @Action='GetItemIssueDtlsById'
BEGIN
     SELECT I.IssueId,I.ItemId, I.MachineId, I.IssueQty, I.ReturnedQty, I.OperatorId, I.IssuedOn , I.Remarks FROM ItemIssue I
	 where IsActive=1 and IssueId=@IssueId   
END
ELSE IF @Action='GetItemReturnDtls'
BEGIN
    Select IR.ReturnId, IM.PartNo +' - '+IM.Description as PartNo_Description,M.MachineCode + ' - ' + M.MachineName as MachineCode_Name,
	E.EmpName as ReturnedBy, IR.ReturnQty, IR.ReturnedOn,IR.Status, IR.Remarks
	from ItemReturn IR
	inner join ItemIssue I on I.IssueId=IR.IssueId and I.IsActive=1 
	inner join ItemMaster IM on IM.ItemId=I.ItemId and IM.IsActive=1  
	inner join MachineDetails M on M.MachineId=I.MachineId and M.IsActive=1 
	inner join EmployeeDetails E on E.EmpId=IR.ReturnedBy and E.IsActive=1 
	where IR.IsActive=1 and @OperatorId in (0,I.OperatorId) and @ItemId in (0,I.ItemId) and @MachineId in (0,I.MachineId)
	ORDER BY IR.ReturnId DESC
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[ItemOpenStockSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ItemOpenStockSP]
								 (
								 @Action varchar(75)=null,
								 @OpenStockEntryId int =0,
								 @ItemId int =0,
								 @Date varchar(20)=null,
								 @Qty varchar(20)=null,
								 @CreatedBy int=0
								 )
AS
BEGIN 
TRY
BEGIN TRANSACTION 
IF @Action='InsertItemOpenStock'
BEGIN

       Update ItemOpenStock SET IsActive=0 where ItemId=@ItemId ;
	   SET @OpenStockEntryId=ISNULL((SELECT TOP 1 OpenStockEntryId+1 FROM ItemOpenStock ORDER BY OpenStockEntryId DESC),1);
	   INSERT INTO ItemOpenStock
								(
								OpenStockEntryId,
								ItemId,
								Date,
								Qty,
								CreatedBy
								)
					VALUES
							  (
							  @OpenStockEntryId,
							  @ItemId,
							  @Date,
							  @Qty,
							  @CreatedBy
							  )
       
       Update ItemStock SET IsActive=0 where ItemId=@ItemId ;
	   INSERT INTO ItemStock
								(
								ItemId,
								Qty,
								CreatedBy
								)
					VALUES
							  (
							  @ItemId,
							  @Qty,
							  @CreatedBy
							  )
			SELECT '1'

	
END
ELSE IF @Action='GetItemOpenStkDtls'
BEGIN
    SELECT  OI.Date, I.PartNo, I.Description , OI.Qty FROM ItemOpenStock OI
	inner join ItemMaster I on I.ItemId=OI.ItemId and I.IsActive=1 
	where OI.IsActive=1  ORDER BY OI.OpenStockEntryId DESC
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[ItemSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ItemSP]
                     (
					 @Action varchar(75)=null,
					 @ItemId int =0,
					 @PartNo varchar(50)=null,
					 @Description varchar(100)=null,
					 @ItemTypeId int =0,
					 @ItemShape varchar(20)=null,
					 @DrawingNumber varchar(50)=null,
					 @HSNNumber varchar(20)=null,
					 @Price varchar(20)=null,
					 @UomId int =0,
					 @ManagedBy varchar(20)=null,
					 @TaxId int =0,
					 @Tolerance varchar(20)=null,
					 @Status varchar(20)=null,
					 @InValidTill varchar(20)=null,
					 @ReOrderQty varchar(20)=null,
					 @Createdby int =0,
						 @SearchString VARCHAR(200)=NULL,
						   @FirstRec INT =0,
						   @LastRec INT =0,
						   @DisplayStart INT =0,
						   @DisplayLength INT =0,
						   @Sortcol INT =0,
						   @SortDir varchar(10)=null,
						   @ItemTypeName VARCHAR(75)=NULL
						   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertItem'
BEGIN
   IF @ItemId=0
   BEGIN
       SET @ItemId=ISNULL((SELECT TOP 1  ItemId+1 FROM ItemMaster ORDER BY ItemId DESC),1)
   END
   ELSE
   BEGIN
       UPDATE ItemMaster SET IsActive=0 WHERE ItemId=@ItemId;
   END
      INSERT INTO ItemMaster
	                        (
							[ItemId]
						   ,[PartNo]
						   ,[Description]
						   ,[ItemTypeId]
						   ,[ItemShape]
						   ,[DrawingNumber]
						   ,[HSNNumber]
						   ,[Price]
						   ,[UOMId]
						   ,[ManagedBy]
						   ,[TaxId]
						   ,[Tolerance]
						   ,[Status]
						   ,[InvalidTill]
						   ,[ReOrderQty]
						   ,[CreatedBy]
						   )
					VALUES
					      (
						    @ItemId
						   ,@PartNo
						   ,@Description
						   ,@ItemTypeId
						   ,@ItemShape
						   ,@DrawingNumber
						   ,@HSNNumber
						   ,@Price
						   ,@UOMId
						   ,@ManagedBy
						   ,@TaxId
						   ,@Tolerance
						   ,@Status
						   ,@InvalidTill
						   ,@ReOrderQty
						   ,@CreatedBy
					      )
				SELECT '1'
END

ELSE IF @Action='GetItemDtls'
BEGIN
 Set @FirstRec=@DisplayStart;
        Set @LastRec=@DisplayStart+@DisplayLength;

        Select * from (
        Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.ItemId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.PartNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.PartNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Description	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Description	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.ItemTypeName end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.ItemTypeName end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.ItemShape	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.ItemShape end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.Status end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.Status end desc
                     ) as RowNum  
					 from (	
					  Select I.ItemId,I.PartNo,I.Description,IT.ItemTypeName,I.ItemShape,I.Status
					  ,COUNT(*) over() as TotalCount  from
	                  ItemMaster I
	                  INNER JOIN ItemTypeMaster  IT ON IT.ItemTypeId = I.ItemTypeId AND IT.IsActive=1
	                  WHERE I.IsActive=1 
					 )A where (@SearchString is null or A.PartNo like '%' +@SearchString+ '%' or
									A.Description like '%' +@SearchString+ '%' or A.ItemTypeName like '%' +@SearchString+ '%' or
									A.ItemShape like '%' + @SearchString+ '%' or A.Status like '%' +@SearchString)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
	
END
ELSE IF @Action='GetItemDtlsById'
BEGIN
    sELECT PartNo,Description,ItemTypeId,ItemShape,DrawingNumber,HSNNumber,
	Price,UOMId,ManagedBy,TaxId,Tolerance,Status,InvalidTill,ReOrderQty FROM ItemMaster 
	WHERE IsActive=1 AND ItemId=@ItemId;
END
ELSE IF @Action='InsertItemType'
BEGIN
   SET @ItemTypeId =ISNULL((SELECT TOP 1 ItemTypeId+1 FROM  ItemTypeMaster ORDER BY ItemTypeId DESC),1);
   INSERT INTO ItemTypeMaster
							(
							ItemTypeId,
							ItemTypeName,
							CreatedBy
							)
					VALUES
							(
							@ItemTypeId,
							@ItemTypeName,
							@Createdby
							)
		SELECT '1'

END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[JobOrderInspectionSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JobOrderInspectionSP]
									(
									@Action varchar(75)=null,
									@JobOrderInspectionId int =0,
									@InspectionDate varchar(20)=null,
									@JobOrderPOId int =0,
									@JobOrderPOSubId int =0,
									@DCNo varchar(20)=null,
									@DCDate varchar(20)=null,
									@SampleSize varchar(50)=null,
									@Attachments varchar(max)=null,
									@Remarks varchar(max)=null,
									@AccQty varchar(20)=null,
									@RejQty varchar(20)=null,
									@InspectedBy int =0,
									@ApprovedBy int =0,
									@CreatedBy int =0,
									@JobOrderInspectionSub JobOrderInspectionSub READONLY,
									@FromDate varchar(20)=null,
									@ToDate varchar(20)=null
									)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertJobOrderInspection'
BEGIN
     IF @JobOrderInspectionId=0
	 BEGIN
	     SET @JobOrderInspectionId =ISNULL((SELECT TOP 1 JobOrderInspectionId+1 FROM JobOrderInspectionMain ORDER BY JobOrderInspectionId DESC),1);
	 END
	 ELSE
	 BEGIN
	     UPDATE JobOrderInspectionMain SET IsActive=0 WHERE JobOrderInspectionId=@JobOrderInspectionId;
	     UPDATE JobOrderInspectionSub SET IsActive=0 WHERE JobOrderInspectionId=@JobOrderInspectionId;
	 END
	     INSERT INTO [dbo].[JobOrderInspectionMain]
								   (
								    [JobOrderInspectionId]
								   ,[InspectionDate]
								   ,[JobOrderPOId]
								   ,[JobOrderPOSubId]
								   ,[DCNo]
								   ,[DCDate]
								   ,[SampleSize]
								   ,[Attachments]
								   ,[Remarks]
								   ,[AccQty]
								   ,[RejQty]
								   ,[InspectedBy]
								   ,[ApprovedBy]
								   ,[CreatedBy]
								   )
						VALUES
								( 
								    @JobOrderInspectionId
								   ,@InspectionDate
								   ,@JobOrderPOId
								   ,@JobOrderPOSubId
								   ,@DCNo
								   ,@DCDate
								   ,@SampleSize
								   ,@Attachments
								   ,@Remarks
								   ,@AccQty
								   ,@RejQty
								   ,@InspectedBy
								   ,@ApprovedBy
								   ,@CreatedBy
								   )
	INSERT INTO [dbo].[JobOrderInspectionSub]
						   (
						    [JobOrderInspectionId]
						   ,[Parameter]
						   ,[Specification]
						   ,[Instrument]
						   ,[Value1]
						   ,[Value2]
						   ,[Value3]
						   ,[Value4]
						   ,[Value5]
						   ,[Value6]
						   ,[Value7]
						   ,[Value8]
						   ,[CreatedBy]
						   )
			      SELECT    @JobOrderInspectionId
			               ,[Parameter]
						   ,[Specification]
						   ,[Instrument]
						   ,[Value1]
						   ,[Value2]
						   ,[Value3]
						   ,[Value4]
						   ,[Value5]
						   ,[Value6]
						   ,[Value7]
						   ,[Value8]
						   ,@CreatedBy from @JobOrderInspectionSub;
	
	Update JobOrderPOSub set IsInspected=1 where JobOrderPOId=@JobOrderPOId and JobOrderPOSubId=@JobOrderPOSubId and isActive='1'
			SELECT '1'    
END
ELSE IF @Action='GetJobOrderInspectionDtls'
BEGIN
        SELECT JI.JobOrderInspectionId, JM.PONo,CM.CustomerName,JS.ItemName + ' (' + JS.PartNo +')' as PartNo_ItemName , JI.AccQty, JI.RejQty,JI.Remarks,
		AE.EmpName as ApprovedByName , IE.EmpName as InspectedByName,
		case when R.ItemId is null then 'false' else 'true' end as RouteCardStatus
		  FROM JobOrderInspectionMain JI
		inner join JobOrderPOMain JM on JM.JobOrderPOId=JI.JobOrderPOId and JM.IsActive=1 
		inner join JobOrderPOSub JS on JS.JobOrderPOId=JI.JobOrderPOId and JS.JobOrderPOSubId=JI.JobOrderPOSubId and JS.IsActive=1 
		inner join EmployeeDetails AE on AE.EmpId =JI.ApprovedBy and AE.IsActive=1  
		inner join EmployeeDetails IE on IE.EmpId =JI.InspectedBy and IE.IsActive=1
		inner join CustomerMaster CM on CM.CustomerId=JM.CustomerId and CM.IsActive=1
		left  join (Select R.PrePOId, R.ItemId from RouteCardEntry R where R.isactive=1 and R.potype='JobOrderPO' group by R.PrePOId, R.ItemId ) R on R.PrePOId=JI.JobOrderPOId and R.ItemId=JI.JobOrderPOSubId
	    WHERE JI.IsActive=1 and CAST(JI.InspectionDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date) 
		order by  JI.JobOrderInspectionId desc

END
ELSE IF @Action='GetJobOrderInspectionDtlsById'
BEGIN
	Select JI.JobOrderInspectionId,JI.InspectionDate,JI.JobOrderPOId,JI.JobOrderPOSubId,JI.DCNo,JI.DCDate,JI.SampleSize,JI.Attachments,JI.Remarks,JI.AccQty,JI.RejQty,JI.InspectedBy,JI.ApprovedBy,
	JM.Date as Podate , C.CustomerName , JS.Qty as PoQty
	FROM JobOrderInspectionMain JI
	Inner Join JobOrderPOMain JM ON JM.JobOrderPOId = JI.JobOrderPOId AND JM.IsActive=1
	Inner join JobOrderPOSub JS ON JS.JobOrderPOId= JM.JobOrderPOId and JS.JobOrderPOSubId=JI.JobOrderPOSubId  AND JS.IsActive=1
	Inner join CustomerMaster C ON C.CustomerId= JM.CustomerId AND C.IsActive=1
	Where JI.IsActive=1 AND JI.JobOrderInspectionId = @JobOrderInspectionId

	Select JobOrderInspectionId,Parameter,Specification,Instrument,Value1,Value2,Value3,Value4,Value5,Value6,Value7,Value8
	FROM JobOrderInspectionSub JI
    Where JI.IsActive=1 AND JI.JobOrderInspectionId = @JobOrderInspectionId

END


COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[JobOrderPOSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JobOrderPOSP]
							 (
							 @Action varchar(75)=null,
							 @JobOrderPOId int =0,
							 @PONo varchar(20)=null,
							 @Date varchar(20)=null,
							 @CustomerId int =0,
							 @RefNo varchar(20)=null,
							 @RefDate varchar(20)=null,
							 @Remarks varchar(max)=null,
							 @Status varchar(20)=null,
							 @CreatedBy int =0, 
							 @JobOrderPOSub JobOrderPOSub readonly		,
							 
							  @SearchString VARCHAR(200)=NULL,
							 @FirstRec INT =0,
							 @LastRec INT =0,
							 @DisplayStart INT =0,
							 @DisplayLength INT =0,
							 @Sortcol INT =0,
							 @SortDir varchar(10)=null
			
							 )
AS
BEGIN TRY
BEGIN TRANSACTION
IF @Action='InsertJobOrderPO'
BEGIN
    IF @JobOrderPOId=0
	BEGIN
	     SET @JobOrderPOId=ISNULL((SELECT TOP 1 JobOrderPOId+1 FROM JobOrderPOMain ORDER BY JobOrderPOId DESC ),1);
	END
	ELSE
	BEGIN
	    UPDATE JobOrderPOMain SET IsActive=0 where JobOrderPOId=@JobOrderPOId;
	    UPDATE JobOrderPOSub SET IsActive=0 where JobOrderPOId=@JobOrderPOId;
	END
			INSERT INTO [dbo].[JobOrderPOMain]
				   (
				   [JobOrderPOId]
				   ,[PONo]
				   ,[Date]
				   ,[CustomerId]
				   ,[RefNo]
				   ,[RefDate]
				   ,[Remarks]
				   ,[Status]
				   ,[CreatedBy]
				   )
			VALUES
					(
					@JobOrderPOId
				   ,@PONo
				   ,@Date
				   ,@CustomerId
				   ,@RefNo
				   ,@RefDate
				   ,@Remarks
				   ,@Status
				   ,@CreatedBy
				   )
		INSERT INTO [dbo].[JobOrderPOSub]
							   (
							    [JobOrderPOId]
							   ,[JobOrderPOSubId]
							   ,[PartNo]
							   ,[ItemName]
							   ,[Qty]
							   ,[InvoiceBalQty]
							   ,[UOMId]
							   ,[Status]
							   ,[DeliveryStatus]
							   ,[IsInspected]
							   ,[CreatedBy]
							   )
					SELECT    @JobOrderPOId,
							 ROW_NUMBER() OVER(ORDER BY (SELECT 1))
							,[PartNo]
							,[ItemName]
							,[Qty]
							,[Qty]
							,[UOMId]
							,[Status]
							,[DeliveryStatus]
							,[IsInspected]
							,@CreatedBy from @JobOrderPOSub
		SELECT '1'
			     
END
ELSE IF @Action='GetJobOrderPODtls'
BEGIN
          set @FirstRec=@DisplayStart;
        Set @LastRec=@DisplayStart+@DisplayLength;


        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.JobOrderPOId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.PONo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Date	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.RefNo end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.RefNo end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.RefDate	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.RefDate end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.CustomerName end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.CustomerName end desc	,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.Status end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.Status end desc	
								    
                     ) as RowNum  
					 from (		
						Select JM.JobOrderPOId, JM.PONo, JM.Date, JM.RefNo, JM.RefDate,C.CustomerName, JM.Status, 	COUNT(*) over() as TotalCount 
						from JobOrderPOMain JM
						inner join CustomerMaster C on C.CustomerId=JM.CustomerId and C.IsActive=1 
						where JM.IsActive=1 )A where (@SearchString is null or A.PONo like '%' +@SearchString+ '%' or A.Date like '%' +@SearchString+ '%' or
									A.RefNo like '%' +@SearchString+ '%' or A.RefDate like '%' +@SearchString+ '%' or
									A.CustomerName like '%' + @SearchString+ '%' or A.Status like '%' + @SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
						
END
ELSE IF @Action='GetJobOrderPODtlsById'
BEGIN
     SELECT JM.PONo, JM.Date,JM.CustomerId, JM.RefNo, JM.RefDate, JM.Status, JM.Remarks  FROM JobOrderPOMain JM
	 WHERE JM.IsActive=1 and JM.JobOrderPOId = @JobOrderPOId;

      Select JS.JobOrderPOSubId, JS.PartNo, JS.ItemName, JS.Qty, JS.UOMId, JS.Status, JS.DeliveryStatus, JS.IsInspected  from JobOrderPOSub JS
	 where JS.IsActive=1 and JS.JobOrderPOId = @JobOrderPOId;
END
ELSE IF @Action='GetJobOrderPONoDtls'
BEGIN
   SELECT JM.JoborderPOId, JM.PONo,JM.Date, C.CustomerName FROM JobOrderPOMain JM
   inner join CustomerMaster C on C.CustomerId=JM.CustomerId and C.IsActive=1 
   where JM.IsActive=1 
END
ELSE IF @Action='GetJobOrderPOSubDtlsById'
BEGIN
     Select JS.JobOrderPOSubId, JS.PartNo + '-'+  JS.ItemName as PartNo_ItemName , JS.Qty from JobOrderPOSub JS
	 where JS.IsActive=1 and JS.JoborderPOId=@JoborderPOId;
END
							  
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[JobWorkInspectionSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[JobWorkInspectionSP]	
									(
									@Action varchar(75)=null,
									@JWId int =0,
									@JWNo varchar(20)=null,
									@JWDate varchar(20)=null,
									@POType varchar(20)=null,
									@InwardId int =0,
									@SupplierId int =0,
									@PrePOId int =0,
									@ItemId int =0,
									@RouteEntryId int =0,
									@RoutLineNo int =0,
									@OperationId int =0,
									@RawMaterialId int =0,
									@Accqty varchar(20)=null,
									@ReworkQty varchar(20)=null,
									@Outqty varchar(20)=null,
									@ReworkReasonId int =0,
									@RejQty varchar(20)=null,
									@RejReasonId int =0,
									@Attachment varchar(max)=null,
									@CreatedBy int =0,
									@FromDate varchar(20)=null,
									@ToDate varchar(20)=null,
									@ReWork bit=0,
							    	@MaterialOutDCSubId int=0,
									@FinalRoutLineNo int =0,
									@FinalProcessProdQty varchar(20)=null,
								   --Optimized Query
									@FirstRec int=0,
									@SortDir varchar(10)=null,
									@SearchString varchar(20)=null,
									@DisplayStart int=0,
									@DisplayLength int=0,
									@SortCol int=0,
									@LastRec int=0,
									@VendorId int =0
									)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action ='InsertJW'
BEGIN
    SET @JWID=ISNULL((SELECT TOP 1 JWId+1 FROM JobWorkInspection ORDER BY JWId DESC),1);
	SET @JWNo=@JWId;
	INSERT INTO JobWorkInspection
								 (
								 JWId,
								 JWNo,
								 JWDate,
								 POType,
								 InwardId,
								 MaterialOutDCSubId,
								 SupplierId,
								 PrePOId,
								 ItemId,
								 RouteEntryId,
								 RoutLineNo,
								 OperationId,
								 RawMaterialId,
								 AccQty,
								 ReworkQty,
								 ReworkBAlQty,
								 OutQty,
								 ReworkReasonId,
								 RejQty,
								 RejReasonId,
								 Rework,
								 Attachment,
								 CreatedBy
								 )
						VALUES
								(
								 @JWId,
								 @JWNo,
								 @JWDate,
								 @POType,
								 @InwardId,
								 @MaterialOutDCSubId,
								 @SupplierId,
								 @PrePOId,
								 @ItemId,
								 @RouteEntryId,
								 @RoutLineNo,
								 @OperationId,
								 @RawMaterialId,
								 @AccQty,
								 case when  @ReworkQty is null or @ReworkQty ='' then '0' else @ReworkQty end,
								 case when  @ReworkQty is null or @ReworkQty ='' then '0' else @ReworkQty end,
								 '0',
								 @ReworkReasonId,
								 case when  @RejQty is null or @RejQty ='' then '0' else @RejQty end,
								 @RejReasonId,
								 @Rework,
								 @Attachment,
								 @CreatedBy
								 )
	IF @ReWork='0'
	BEGIN
	Update InwardDCSub Set InspectStatus='true' where InwardId=@InwardId and RouteEntryId=@RouteEntryId and RoutLineNo=@RoutLineNo;
	Update InwardDCMain Set InspectStatus='true' where InwardDCId=@InwardId; 
    END
	ELSE
	BEGIN
	   Update MaterialOutInwardSub SET InspectionStatus='true' where InwardId=@InwardId and MaterialOutDCSubId=@MaterialOutDCSubId;
	END
	
	  IF NOT EXISTS(SELECT TOP 1 RouteEntryId  FROM POProcessQtyDetails WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RoutLineNo  AND IsActive=1)
	BEGIN
		 INSERT INTO POProcessQtyDetails
									(
									POType,
									PrePOId,
									ItemId,
									RouteEntryId,
									RoutLineNo,
									TotalAccQty,
									AccQty,
									ReworkQty,
									RejQty,
									CreatedBy
									)
						 VALUES
								  (
								  @POType,
								  @PrePOId,
								  @ItemId,
								  @RouteEntryId,
								  @RoutLineNo,
								  cast(isnull(@AccQty ,'0') as float),
								  cast(isnull(@AccQty ,'0') as float),
								  cast(isnull(@ReworkQty ,'0') as float),
								   cast(isnull(@RejQty ,'0') as float) ,
								  @CreatedBy
								  )
    END
   ELSE
   BEGIN 
       UPDATE POProcessQtyDetails SET AccQty=CAST(ISNULL(AccQty,'0')  AS FLOAT) + cast(isnull(@AccQty ,'0') as float) ,
									  TotalAccQty=CAST(ISNULL(TotalAccQty,'0')  AS FLOAT) + cast(isnull(@AccQty ,'0') as float) ,
									  ReworkQty=CAST(ISNULL(ReworkQty,'0')  AS FLOAT) + cast(isnull(@ReworkQty ,'0') as float),
									  RejQty=CAST(ISNULL(RejQty,'0')  AS FLOAT) + cast(isnull(@RejQty ,'0') as float)
	   WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RoutLineNo AND IsActive=1 
      
   END


	SET @FinalRoutLineNo =(SELECT TOP 1 RoutLineNo FROM RouteCardEntry R where R.IsActive=1 and RouteEntryId=@RouteEntryId order by RoutLineNo desc);
	set @FinalProcessProdQty=(SELECT TOP 1 AccQty FROM POProcessQtyDetails P WHERE P.IsActive=1 AND P.RouteEntryId=@RouteEntryId AND RoutLineNo=@FinalRoutLineNo);
	IF @POType='CustomerPO'
	BEGIN
	    UPDATE PrePOSub  SET Status='Closed' , ClosedOn=getDate()
		WHERE PrePOId=@PrePOId and ItemId=@ItemId AND ISACTIVE=1  and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE PM  SET Status='Closed' , ClosedOn=getDate() 
		FROM PrePOMain PM
		INNER JOIN (
				SELECT 	COUNT(CASE when PS.Status='Closed' then 1 else null end ) as ClosedCount, Count(PS.ItemId) as TotalCount
				FROM PrePOSub PS
				WHERE PS.IsActive=1 and PS.PrePOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount 
	     IF @RoutLineNo=@FinalRoutLineNo
		 BEGIN
		      IF EXISTS(SELECT TOP 1 ItemId FROM ItemStock WHERE ItemId=@ItemId and IsActive=1 )
			  BEGIN
			     UPDATE ItemStock SET Qty = CAST(ISNULL(QTY,'0') AS decimal(18,2)) + cast(isnull(@AccQty ,'0') as float)
				 WHERE ItemId=@ItemId and IsActive=1 
			  END
			  ELSE
			  BEGIN
				   INSERT INTO ItemStock
									(
									ItemId,
									Qty,
									CreatedBy
									)
						VALUES
								  (
								  @ItemId,
								  cast(isnull(@AccQty ,'0') as float),
								  @CreatedBy
								  )
			      
			  END
		 END
	END
	ELSE
	BEGIN
	    UPDATE JobOrderPOSub  SET Status='Closed' , ClosedOn=getDate()
		WHERE JobOrderPOId=@PrePOId and JobOrderPOSubId=@ItemId AND ISACTIVE=1  and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE JM  SET Status='Closed' , ClosedOn=getDate() 
		FROM JobOrderPOMain JM
		INNER JOIN (
				SELECT 	COUNT(CASE when JS.Status='Closed' then 1 else null end ) as ClosedCount, Count(JS.JobOrderPOSubId) as TotalCount
				FROM JobOrderPOSub JS
				WHERE JS.IsActive=1 and JS.JobOrderPOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount  
	END

					Select '1'
END

ELSE IF @Action='GetInwardDtlsForJobWorkIns'
BEGIN
       ---From Inward DC 
		 SELECT IM.InwardDCId,0 as MaterialOutDCSubId, IM.InwardDCNo, IM.InwardDCDate,IM.VendorId, C.CustomerName as VendorName,
		ISNULL(PM.PrePONo,JM.PONo) as PrePONo,	ID.PrePOId, ID.ItemId, ID.RouteEntryId, ID.RoutLineNo , ID.OperationId,
		case when @POType='CustomerPO' then I.PartNo+'-'+I.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
		RM.CodeNo+'-' + RM.Description as RawMaterial,isnull(RM.RawMaterialId,0) as RawMaterialId,
		cast(ID.RoutLineNo as varchar)+'-'+O.OperationName as Operation,
		ID.InwardDCQty as Qty
		FROM InwardDCSub ID
		inner join InwardDCMain IM  on IM.InwardDCId=ID.InwardId and IM.IsActive=1
		left join PrePOMain PM on @POType='CustomerPO' and  PM.PrePOId =ID.PrePOId and PM.isActive=1
		left join JobOrderPOMain JM on   @POType='JobOrderPO' and  JM.JobOrderPOId =ID.PrePOId and JM.isActive=1
		left join ItemMaster I on @POType='CustomerPO' and I.ItemId=ID.ItemId and I.IsActive=1
		left join RawMaterial RM on @POType='CustomerPO' and  RM.RawMaterialId =ID.RawMaterialId and RM.IsActive=1
		left join JobOrderPOSub JS on @POType='JobOrderPO' and JS.JobOrderPOId=ID.PrePOId and JS.JobOrderPOSubId=ID.ItemId and JS.IsActive=1 
		inner join CustomerMaster C on C.CustomerId=IM.VendorId and C.IsActive=1
		inner join OperationMaster O on O.OperationId=ID.OperationId and O.IsActive=1
		WHERE ID.IsActive=1 and IM.POType=@POType  and ID.InspectStatus='false' and CAST(IM.InwardDCDate as date) between CAST(@FromDate as date) and cast(@ToDate as date)
		order by IM.InwardDCId desc;

		---From Material Out DC Inward
		Select ID.InwardId as InwardDCId,ID.MaterialOutDCSubId, IM.InwardNo as InwardDCNo, IM.InwardDate as InwardDCDate,IM.CustomerId as VendorId,C.CustomerName as VendorName,
		ISNULL(PM.PrePONo,JM.PONo) as PrePONo,JW.PrePOId,JW.ItemId,JW.RouteEntryId,JW.RoutLineNo,JW.OperationId,
		case when @POType='CustomerPO' then I.PartNo+'-'+I.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
		RM.CodeNo+'-' + RM.Description as RawMaterial,RM.RawMaterialId,
		cast(JW.RoutLineNo as varchar)+'-'+O.OperationName as Operation,
		ID.Qty
		from MaterialOutInwardSub ID
		inner join MaterialOutInwardMain IM on IM.inwardId=ID.InwardId and IM.Isactive=1
		inner join JobWorkInspection JW on JW.JWId=ID.QCId and JW.IsActive=1 and JW.POType=@POType
		left join PrePOMain PM on @POType='CustomerPO' and  PM.PrePOId =JW.PrePOId and PM.isActive=1
		left join JobOrderPOMain JM on   @POType='JobOrderPO' and  JM.JobOrderPOId =JW.PrePOId and JM.isActive=1
		left join ItemMaster I on @POType='CustomerPO' and I.ItemId=JW.ItemId and I.IsActive=1
		left join RawMaterial RM on @POType='CustomerPO' and  RM.RawMaterialId =JW.RawMaterialId and RM.IsActive=1		
		left join JobOrderPOSub JS on @POType='JobOrderPO' and JS.JobOrderPOId=JW.PrePOId and JS.JobOrderPOSubId=JW.ItemId and JS.IsActive=1 
		inner join OperationMaster O on O.OperationId=JW.OperationId and O.IsActive=1
		inner join CustomerMaster C on C.CustomerId=IM.CustomerId and C.IsActive=1
		where ID.IsActive=1 and JW.POType=@POType and ID.Type='Rework' and ID.InspectionStatus='false' and CAST(IM.InwardDate as date) between CAST(@FromDate as date) and cast(@ToDate as date)
		order by IM.InwardId desc;
END
ELSE IF @Action='GetJWDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.JWID end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.JWNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.JWNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.JWDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.JWDate end desc,	
			                 case when (@SortCol =3 and  @SortDir ='asc')  then A.InwardNo	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.InwardNo	end desc ,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.InwardDate	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.InwardDate	end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.VendorName	end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.VendorName	end desc,
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.VendorDCNo	end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.VendorDCNo	end desc,
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.VendorDCDate end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.VendorDCDate end desc,	
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.PartNo_Description end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.PartNo_Description end desc,
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.RawMaterial end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.RawMaterial end desc,	
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.Process end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.Process end desc,	
							 case when (@SortCol =12 and  @SortDir ='asc')  then A.InwardQty end asc,
							 case when (@SortCol =12 and  @SortDir ='desc') then A.InwardQty end desc,
							 case when (@SortCol =13 and  @SortDir ='asc')  then A.AccQty end asc,
							 case when (@SortCol =13 and  @SortDir ='desc') then A.AccQty end desc,	
							 case when (@SortCol =14 and  @SortDir ='asc')  then A.ReworkQty end asc,
							 case when (@SortCol =14 and  @SortDir ='desc') then A.ReworkQty end desc,
							 case when (@SortCol =15 and  @SortDir ='asc')  then A.ReworkReason end asc,
							 case when (@SortCol =15 and  @SortDir ='desc') then A.ReworkReason end desc,	
							 case when (@SortCol =16 and  @SortDir ='asc')  then A.Rejqty end asc,
							 case when (@SortCol =16 and  @SortDir ='desc') then A.Rejqty end desc,	
							 case when (@SortCol =17 and  @SortDir ='asc')  then A.RejReason end asc,
							 case when (@SortCol =17 and  @SortDir ='desc') then A.RejReason end desc,
							 case when (@SortCol =18 and  @SortDir ='asc')  then A.InspectedBy end asc,
							 case when (@SortCol =18 and  @SortDir ='desc') then A.InspectedBy end desc
							
                     ) as RowNum  
		
					 from (	
							   Select J.JWID, J.JWNo,J.JWDate,J.Attachment,isnull(IM.InwardDCNo,MI.InwardNo) as InwardNo,isnull(IM.InwardDCDate,MI.InwardDate) as InwardDate,
								C.CustomerName as VendorName, isnull(IM.VendorDCNo,MI.RefNo) as VendorDCNo , isnull(IM.VendorDCDate,MI.RefDate) as VendorDCDate,
								ISNULL(PM.PrePONo,JM.PONo) as PONo,
								case when J.POType='CustomerPO' then I.PartNo+'-'+I.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
								RM.CodeNo+'-' + RM.Description as RawMaterial, cast(J.RoutLineNo as varchar)+' - '  + O.OperationName as Process,
								isnull(ID.InwardDCQty,MS.Qty) as InwardQty, J.AccQty,J.ReworkQty,RW.Rework as ReworkReason,J.RejQty, RJ.Rejection as RejReason,
								E.EmpName as InspectedBy,Count(*)Over() as TotalCount
								from JobWorkInspection J
								 inner join OperationMaster O on O.OperationId=J.OperationId and O.IsActive=1 
								left join PrePOMain PM on J.POType='CustomerPO' and  PM.PrePOId =J.PrePOId and PM.isActive=1
								left join JobOrderPOMain JM on   J.POType='JobOrderPO' and  JM.JobOrderPOId =J.PrePOId and JM.isActive=1
								left join ItemMaster I on J.POType='CustomerPO' and I.ItemId=J.ItemId and I.IsActive=1
								left join RawMaterial RM on J.POType='CustomerPO' and  RM.RawMaterialId =J.RawMaterialId and RM.IsActive=1		
								left join JobOrderPOSub JS on J.POType='JobOrderPO' and JS.JobOrderPOId=J.PrePOId and JS.JobOrderPOSubId=J.ItemId and JS.IsActive=1 
								left join InwardDCMain IM on J.Rework=0 and IM.InwardDCId=J.InwardId and IM.IsActive=1 
								left join MaterialOutInwardMain MI on J.Rework=1 and MI.InwardId=J.InwardId and MI.IsActive=1 
								left join InwardDCSub ID on J.Rework=0 and ID.InwardId=J.InwardId and ID.RouteEntryId=J.RouteEntryId and ID.RoutLineNo=J.RoutLineNo and ID.IsActive=1
								left join MaterialOutInwardSub MS on J.Rework=1 and MS.InwardId=J.InwardId and MS.MaterialOutDCSubId=J.MaterialOutDCSubId and MS.IsActive=1 
								inner join CustomerMaster C on C.CustomerId=case when J.Rework=0 then IM.VendorId else MI.CustomerId end and  C.IsActive=1
								left join ReworkReason  RW on RW.ReworkReasonId=J.ReworkReasonId and RW.IsActive=1 
								left join RejectionReason RJ on RJ.RejectionReasonId=J.RejReasonId and RJ.IsActive=1 
								inner join EmployeeDetails E on E.EmpId=J.CreatedBy and E.IsActive=1 
								where J.IsActive=1 AND J.POType=@POType
					    )A where (@SearchString is null  or A.JWNo like '%' +@SearchString+ '%' or A.JWDate like '%' + @SearchString+ '%' or 
									A.InwardNo like '%' + @SearchString+ '%' or 	A.InwardDate like '%' + @SearchString+ '%' or 
									A.VendorName like '%' + @SearchString+ '%' or  	A.VendorDCNo like '%' + @SearchString+ '%' or 
									A.VendorDCDate like '%' + @SearchString+ '%' or A.PONo like '%' +@SearchString+ '%' or
									A.PartNo_Description like '%' + @SearchString+ '%' or A.RawMaterial like '%' +@SearchString+ '%' or
									A.InwardQty like '%' + @SearchString+ '%' or  A.Process like '%' +@SearchString+ '%' or
									A.Accqty like '%' + @SearchString+ '%' or A.ReworkQty like '%' +@SearchString+ '%' or 
									A.ReworkReason like '%' + @SearchString+ '%' or A.Rejqty like '%' +@SearchString+ '%' or
									A.RejReason like '%' + @SearchString+ '%' or A.InspectedBy like '%' + @SearchString+ '%'
								  
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END


COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[LoginUserSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[LoginUserSP]
							(
							@Action varchar(75)=null,
							@UserName varchar(20)=null,
							@Password varchar(20)=null,
							@EmpCode varchar(20)=null
							)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='VerifyLoginUser'
BEGIN
    Select *,R.menuIds, 'hideMenu' ='1,4,7,10,13,16,19,22,25,28,31,34,37,40,43,46,49,141,143,221,89,97,114,61,103,146,52,55,58,149,152,118,100,203,173,176,182,185,179,67,122,72,75,107,78,81,84,137,136,64,111,155,218,231,' 
	from  EmployeeDetails E
     inner join Rolemaster R on R.roleID=E.roleId and R.isactive=1
 where E.IsActive=1 AND E.isActive=1 and E.username=@UserName and E.password=@Password;
END
ELSE IF @Action='GetEmpProdLogin'
BEGIN
    SELECT E.EmpId,E.EmpName FROM EmployeeDetails E
	WHERE E.IsActive=1 and E.EmpCode=@EmpCode;
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH




GO
/****** Object:  StoredProcedure [dbo].[MachineOutDcInWardSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[MachineOutDcInWardSP]
    (
									@Action varchar(75)=null,
									@InwardId int =0,
									@InwardNo varchar(20)=null,
									@Date varchar(20)=null,
									@CustomerId int =0,
									@DCId int =0,
									@RefNo varchar(20)=null,
									@RefDate varchar(20)=null,
									@Remarks varchar(max)=null,
									@CreatedBy int =0,
									@MachineOutDcInwardSub MachineOutDcInwardSub READONLY,
									@SearchString VARCHAR(200)=NULL,
									@FirstRec INT =0,
									@LastRec INT =0,
									@DisplayStart INT =0,
									@DisplayLength INT =0,
									@Sortcol INT =0,
									@SortDir varchar(10)=null,
									@RouteEntryId int=0
									)
As
BEGIN 
TRY
BEGIN TRANSACTION

IF @Action='InsertMachineOutInWard'
BEGIN
	IF @InwardId =0
	BEGIN
		SET @InwardId = IsNull((Select Top 1 InwardId+1 From MachineOutInWardMain ORDER BY InwardId Desc),1);
		SET @InwardNo=@InwardId;
	END
	ELSE
	BEGIN
	   UPDATE MS SET MS.InwardBalQty = cast(ISNULL(MS.InwardBalQty,'0') as decimal(18,2)) + cast(ISNULL(MI.RecQty,'0') as decimal(18,2))
	   from MachineWiseDCSub MS
	   INNER JOIN MachineOutInwardSub MI on MI.InwardId=@InwardId and MS.DCId=MI.DCId and MI.IsActive=1
	   where MS.IsActive=1 ; 


       UPDATE MachineOutInwardMain SET IsActive=0 WHERE InwardId=@InwardId;
	   UPDATE MachineOutInwardSub SET IsActive=0 WHERE InwardId=@InwardId;
	END

	INSERT INTO MachineOutInWardMain(
										InwardId,
										InwardNo,
										Date,
										CustomerId,
										DCId,
										RefNo,
										RefDate,
										Remarks,
										CreatedBy
										)
							VALUES
									(
									@InwardId,
									@InwardNo,
									@Date,
									@CustomerId,
									@DCId,
									@RefNo,
									@RefDate,
									@Remarks,
									@CreatedBy
									)
	INSERT INTO MachineOutInwardSub(
			                         InwardId,
									 DCId,
									 MachineId,
									 RecQty,
									 CreatedBy
	                               )
							
							Select
									@InwardId,
									@DCId,
									MachineId,
									ReCQty,
									@CreatedBy From @MachineOutDcInwardSub;

	   UPDATE MS SET MS.InwardBalQty = cast(ISNULL(MS.InwardBalQty,'0') as decimal(18,2))- cast(ISNULL(MI.RecQty,'0') as decimal(18,2))
	   from MachineWiseDCSub MS
	   INNER JOIN @MachineOutDcInwardSub MI on MS.DCId=@DCID 
	   where MS.IsActive=1; 

		SELECT 1
END

ELSE IF @Action='GetDCMachineMainDtlsForInWard'
BEGIN
		Set @DCId =(Select top 1 DCId FROM MachineOutInwardMain WHERE InwardId=@InwardId AND IsActive=1)

		Select  M.DcId,M.DCNo,M.Date,M.NatureOfProcess  
		from MachineWiseDCMain M
		Inner Join MachineWiseDCSub MS ON MS.DCId=M.DCId AND MS.IsActive=1 AND (MS.DCId = @DCId OR CAST(ISNULL(MS.InwardBalQty,'0') as decimal(18,3)) > CAST('0'as decimal))
		Where M.SupplierId=@CustomerId
		group by M.DCId,M.DCNo,M.Date,M.NatureOfProcess
END

ELSE IF @Action ='GetDcMachineSubDtlsForInWard'
BEGIN

		Select M.MachineId,MD.MachineName,M.Process,M.Qty as 'DcQty',MS.RecQty,
		(CAST(ISNULL(MS.RecQty,'0') as decimal(18,2)) + CAST(ISNULL(M.InwardBalQty,'0') as decimal(18,2))) as RemainingQty,
		M.Remarks
		From MachineWiseDCSub M
		INNER Join MachineDetails MD ON MD.MachineId=M.MachineId AND MD.IsActive=1
		LEFT JOIN MachineOutInwardSub MS ON MS.InwardId=@InwardId AND MS.IsActive=1
		WHERE M.IsActive=1 AND M.DCId=@DCId
		AND (CAST(ISNULL(MS.RecQty,'0') as decimal(18,2)) + CAST(ISNULL(M.InwardBalQty,'0') as decimal(18,2))) > Cast('0' as decimal)

END

ELSE IF @Action='GetMachineOutInWardDtls'
BEGIN
	Set @FirstRec=@DisplayStart;
     Set @LastRec=@DisplayStart+@DisplayLength;

	     select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.InwardId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.InwardNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.InwardNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.CustomerName	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.CustomerName	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Date end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Date end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.DCNo	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.DCNo end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.DCDate end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.DCDate end desc				    
                     ) as RowNum  
					 from (								
						Select MI.InwardId,MI.InwardNo , C.CustomerName,MI.Date,MD.DCNo, MD.Date as DCDate,
						COUNT(*) over() as TotalCount   from MachineOutInwardMain MI
						inner join MachineWiseDCMain MD on MD.DCId =MI.DCId and MD.IsActive =1 
						inner join CustomerMaster C on C.CustomerId =MI.CustomerId and C.IsActive=1 
						where MI.IsActive=1 
						  )A where (@SearchString is null or A.InwardNo like '%' +@SearchString+ '%' or
									A.CustomerName like '%' +@SearchString+ '%' or A.Date like '%' +@SearchString+ '%' or
									A.DCNo like '%' + @SearchString+ '%' or A.DCDate like '%' +@SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END

Else If @Action='GetMachineOutInWardDtlsById'
BEGIN
	Select M.InwardId, M.InwardNo,M.Date,M.CustomerId,M.DCId,M.RefNo,M.RefDate,M.Remarks,D.Date as DcDate,D.NatureOfProcess
	From MachineOutInwardMain M
	Inner Join MachineWiseDCMain D ON D.DCId = M.DCId AND D.IsActive=1
	WHERE M.InwardId=@InwardId AND M.IsActive=1
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[MachineSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MachineSP]
						 (
						 @Action varchar(75)=null,
						 @MachineId int =0,
						 @MachineCode varchar(20)=null,
						 @MachineName varchar(100)=null,
						 @Type varchar(20)=null,
						 @AMCWarranty VARCHAR(10)=NULL,
						 @VendorId int =0,
						 @StartDate varchar(20)=null,
						 @EndDate varchar(20)=null,
						 @WorkingHours varchar(20)=null,
						 @RatePerHour varchar(20)=null,
						 @LastCalibrationDate varchar(20)=null,
						 @NextCalibrationDate varchar(20)=null,
						 @CalibrationFrequency varchar(10)=null,
						 @HistoryCardNo varchar(20)=null,
						 @IsNotInUse bit =0,
						 @Make varchar(50)=null,
						 @LeastCount varchar(20)=null,
						 @Range varchar(75)=null,
						 @SerialNo varchar(75)=null,
						 @DateOfIncorparation varchar(20)=null,
						 @ErrorLimit varchar(100)=null,
						 @Location varchar(100)=null,
						 @CreatedBy int =0,	
					     @SearchString VARCHAR(200)=NULL,
						 @FirstRec INT =0,
						 @LastRec INT =0,
						 @DisplayStart INT =0,
						 @DisplayLength INT =0,
						 @Sortcol INT =0,
						 @SortDir varchar(10)=null,
						 @Status varchar(20)=null
						 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertMachine'
BEGIN
     IF @MachineId=0
	 BEGIN
	       SET @MachineId=ISNULL((SELECT TOP 1 MachineId+1 FROM MachineDetails ORDER BY MachineId DESC),1)
	 END
	 ELSE
	 BEGIN
	    UPDATE MachineDetails SET IsActive=0 WHERE MachineId=@MachineId;
	 END
	 INSERT INTO [dbo].[MachineDetails]
							   ([MachineId]
							   ,[MachineCode]
							   ,[MachineName]
							   ,[Type]
							   ,[AMCWarranty]
							   ,[VendorId]
							   ,[StartDate]
							   ,[EndDate]
							   ,[WorkingHours]
							   ,[RatePerHour]
							   ,[LastCalibrationDate]
							   ,[NextCalibrationDate]
							   ,[CalibrationFrequency]
							   ,[HistoryCardNo]
							   ,[IsNotInUse]
							   ,[Make]
							   ,[LeastCount]
							   ,[Range]
							   ,[SerialNo]
							   ,[DateOfIncorparation]
							   ,[ErrorLimit]
							   ,[Location]
							   ,[CreatedBy]
							   )
					VALUES
							    (
								@MachineId,
								@MachineCode,
								@MachineName,
								@Type,
								@AMCWarranty,
								@VendorId,
								@StartDate,
								@EndDate,
								@WorkingHours,
								@RatePerHour,
								@LastCalibrationDate,
							    @NextCalibrationDate,
								@CalibrationFrequency,
							    @HistoryCardNo,
							    @IsNotInUse,
							    @Make,
							    @LeastCount,
							    @Range,
							    @SerialNo,
							    @DateOfIncorparation,
							    @ErrorLimit,
							    @Location,
							    @CreatedBy
								)
				UPDATE CalibarationHistory SET RecordNo=@HistoryCardNo WHERE MachineId=@MachineId;
				SELECT '1';
END
ELSE IF @Action='GetMachineDetails'
BEGIN
      set @FirstRec=@DisplayStart;
        set @LastRec=@DisplayStart+@DisplayLength;
				select * 
					from (
					select *,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.MachineId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.MachineCode  end asc,
					case when (@SortCol =1 and  @SortDir ='desc') then A.MachineCode end desc,
					case when (@SortCol =2 and  @SortDir ='asc')  then A.MachineName  end asc,
				    case when (@SortCol =2 and  @SortDir ='desc') then A.MachineName  end desc, 
				    case when (@SortCol =3 and  @SortDir ='asc')  then A.Type  end asc,
					case when (@SortCol =3 and  @SortDir ='desc')  then A.Type end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.CalibrationFrequency  end asc,
				    case when (@SortCol =4 and  @SortDir ='desc')then A.CalibrationFrequency end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.LastCalibrationDate  end asc,
					case when (@SortCol =5 and  @SortDir ='desc') then A.LastCalibrationDate end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.NextCalibrationDate  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.NextCalibrationDate end desc
					)as RowNum from(
						Select M.MachineId, M.MachineCode, M.MachineName, M.Type,M.LastCalibrationDate, M.NextCalibrationDate,
						M.CalibrationFrequency, COUNT(*) over() as TotalCount
						from MachineDetails M
						where M.IsActive=1 AND M.Status=@Status and @Type in ('', M.Type)
			         ) A
                     where (@SearchString is null or
                            A.MachineCode like '%' +@SearchString + '%' or
							A.MachineName like '%' +@SearchString+ '%' or
							A.Type like '%' +@SearchString+ '%' or
							A.Type like '%' +@SearchString + '%' or
							A.NextCalibrationDate like '%'+@SearchString + '%' or
			                A.CalibrationFrequency like '%'+@SearchString + '%'
							))B
							 where  RowNum > @FirstRec and RowNum <= @LastRec
END

ELSE IF @Action='GetMachineDtlsById'
BEGIN

Select M.MachineId,M.MachineCode,M.MachineName,M.Type,M.AMCWarranty,M.VendorId,M.StartDate,M.EndDate,M.WorkingHours,M.RatePerHour,M.LastCalibrationDate,M.NextCalibrationDate,M.CalibrationFrequency,M.HistoryCardNo,M.IsNotInUse,M.Make,M.LeastCount,M.Range,
M.SerialNo,M.DateOfIncorparation,M.ErrorLimit,M.Location
From MachineDetails M WHERE IsActive =1 AND M.MachineId= @MachineId

END

ELSE IF @Action='InActiveMachine'
BEGIN
	Update MachineDetails SET Status='InActive' WHERE MachineId=@MachineId;
	Select '1'
END

						COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[MachineWiseDCSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MachineWiseDCSP]
								(
								@Action varchar(75)=null,
								@DCId int =0,
								@DCNo varchar(20)=null,
								@Date varchar(20)=null,
								@SupplierId int =0,
								@NatureOfProcess varchar(100)=null,
								@Remarks varchar(max)=null,
								@DeliverySchedule varchar(100)=null,
								@VehicleNo varchar(20)=null,
								@AppxValue varchar(20)=null,
								@DrawingEnclosed varchar(10)=null,
								@CreatedBy int =0,
								@MachineWiseDCSub MachineWiseDCSub READONLY,
								@Year varchar(20)=null ,
								 @SearchString VARCHAR(200)=NULL,
								   @FirstRec INT =0,
								   @LastRec INT =0,
								   @DisplayStart INT =0,
								   @DisplayLength INT =0,
								   @Sortcol INT =0,
								   @SortDir varchar(10)=null
								)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertMachineWiseDC'
BEGIN
   IF @DCId =0
   BEGIN
      SET @DCId=ISNULL((SELECT TOP 1 DCId+1 FROM MachineWiseDCMain ORDER BY DCId DESC),1);
	  SET @DcNo=(select format + ' ' + cast(CurrentNumber as varchar)  from SerialNoFormats where Type='DC' and year=@Year);
	 update SerialNoFormats set CurrentNumber=CurrentNumber+1 where type='DC' and year=@Year;

   END
   ELSE
   BEGIN
      UPDATE MachineWiseDCMain SET IsActive=0 WHERE DCId=@DCId;
      UPDATE MachineWiseDCSub SET IsActive=0 WHERE DCId=@DCId;
   END
     INSERT INTO [dbo].[MachineWiseDCMain]
									   ([DCId]
									   ,[DCNo]
									   ,[Date]
									   ,[SupplierId]
									   ,[NatureOfProcess]
									   ,[Remarks]
									   ,[DeliverySchedule]
									   ,[VehicleNo]
									   ,[AppxValue]
									   ,[DrawingEnclosed]
									   ,[CreatedBy]
									   )
							VALUES
									 (
									 @DCId,
									 @DCNo,
									 @Date,
									 @SupplierId,
									 @NatureOfProcess,
									 @Remarks,
									 @DeliverySchedule,
									 @VehicleNo,
									 @AppxValue,
									 @DrawingEnclosed,
									 @CreatedBy
									 )
          INSERT INTO [dbo].[MachineWiseDCSub]
									   (
									   [DCId]
									   ,[MachineId]
									   ,[Process]
									   ,[Qty]
									   ,[InwardBalQty]
									   ,[UnitId]
									   ,[Remarks]
									   ,[CreatedBy]
									   )
						        SELECT  @DCId
									   ,[MachineId]
									   ,[Process]
									   ,[Qty]
									   ,[Qty]
									   ,[UnitId]
									   ,[Remarks]
									   ,@CreatedBy FROM @MachineWiseDCSub;

						SELECT '1'
END
ELSE IF @Action='GetMachineWiseDCDtls'
BEGIN    
       set @FirstRec=@DisplayStart;
        set @LastRec=@DisplayStart+@DisplayLength;

		Select * into  #MachineOutInwardMain from  (Select distinct MI.DCId from MachineOutInwardMain MI where MI.IsActive=1 )A

   
					select * 
					from (
					select *,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.DCId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.DCNo  end asc,
					case when (@SortCol =1 and  @SortDir ='desc') then A.DCNo end desc,
					case when (@SortCol =2 and  @SortDir ='asc')  then A.Date  end asc,
				    case when (@SortCol =2 and  @SortDir ='desc') then A.Date  end desc, 
				    case when (@SortCol =3 and  @SortDir ='asc')  then A.CustomerName  end asc,
					case when (@SortCol =3 and  @SortDir ='desc')  then A.CustomerName end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.NatureOfProcess  end asc,
					case when (@SortCol =5 and  @SortDir ='desc') then A.NatureOfProcess end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.VehicleNo  end asc,
					case when (@SortCol =5 and  @SortDir ='desc') then A.VehicleNo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.DeliverySchedule  end asc,
					case when (@SortCol =6 and  @SortDir ='desc') then A.DeliverySchedule end desc
					)as RowNum from(
					Select MC.DCId, MC.DCNo,MC.Date,C.CustomerName,MC.NatureOfProcess,MC.VehicleNo,MC.DeliverySchedule,
					case when MI.DCId is null then 'false' else 'true' end as InwardStatus,
					COUNT(*) over() as TotalCount   from MachineWiseDCMain MC
					left join #MachineOutInwardMain MI on MI.DCId=MC.DCId
					inner join CustomerMaster C on C.CustomerId =MC.SupplierId and C.IsActive=1 
					where MC.IsActive=1 
			 ) A
					 where (@SearchString is null or

							A.DCNo like '%' +@SearchString + '%' or
							A.Date like '%' +@SearchString+ '%' or
							A.CustomerName like '%' +@SearchString+ '%' or
							A.NatureOfProcess like '%' +@SearchString + '%' OR 
							A.VehicleNo like '%' +@SearchString+ '%' or
							A.DeliverySchedule like '%' +@SearchString + '%'  
						))B
							 where  RowNum > @FirstRec and RowNum <= @LastRec
END
ELSE IF @Action='GetMachineWiseDCDtlsById'
BEGIN
     SELECT DCId, DCNo,Date, SupplierId, NatureOfProcess, Remarks, DeliverySchedule, VehicleNo, AppxValue, DrawingEnclosed FROM MachineWiseDCMain 
	 WHERE IsActive=1 AND DCId=@DCId;

	 SELECT MachineId, Process,Qty,UnitId,Remarks FROM MachineWiseDCSub 
	 WHERE IsActive=1 AND DCId=@DCId;
END


COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[ManualProductionSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ManualProductionSP]
								   (
								   @Action varchar(75)=null,
								   @ManualProdEntryId int =0,
								   @Date varchar(20)=null,
								   @POType varchar(20)=null,
								   @PrePOId int=0,
								   @ItemId int =0,
								   @RouteEntryId int =0,
								   @RouteLineNo int =0,
								   @AccQty varchar(20)=null,
								   @RejQty varchar(20)=null,
								   @ReworkQty varchar(20)=null,
								   @CreatedBy int =0,
								   @SearchString VARCHAR(200)=NULL,
								   @FirstRec INT =0,
								   @LastRec INT =0,
								   @DisplayStart INT =0,
								   @DisplayLength INT =0,
								   @Sortcol INT =0,
								   @SortDir varchar(10)=null,							   
								   @FromDate varchar(20)=null,								   
								   @ToDate varchar(20)=null,
								   @ConvFactor varchar(20)=null,
								   @FinalRoutLineNo int =0,
								   @FinalProcessProdQty varchar(20)=null,
								   @RawMaterialId int=0,
								   @Text1 varchar(20)=null,
								   @Text2 varchar(20)=null,
								   @Text3 varchar(20)=null,
								   @Value1 varchar(20)=null,
								   @Value2 varchar(20)=null,
								   @Value3 varchar(20)=null,
								   @OperationId int =0								   
								   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertManualProduction'
BEGIN	
     SET @ManualProdEntryId=ISNULL((SELECT TOP 1 ManualProdEntryId+1 FROM ManualProductionEntry ORDER BY ManualProdEntryId DESC),1);	 
	 INSERT INTO ManualProductionEntry
									 (
									 ManualProdEntryId,
									 Date,
									 POType,
									 PrePOId,
									 ItemId,
									 RouteEntryId,
									 RoutelineNo,
									 AccQty,
									 RejQty,
									 ReworkQty,
									 CreatedBy
									 )
						VALUES
									(
									@ManualProdEntryId,
									@Date,
									@POType,
									@PrePOId,
									@ItemId,
									@RouteEntryId,
									@RouteLineNo,
									@AccQty,
									@RejQty,
									@ReworkQty,
									@CreatedBy
									)
     SET @ConvFactor=isnull((SELECT TOP 1 CASE WHEN  ConvFact='' THEN '1' ELSE ConvFact end FROM RouteCardEntry WHERE RouteEntryId =@RouteEntryId AND RoutLineNo=@RouteLineNo AND IsActive=1 ),'1')
     IF NOT EXISTS(SELECT TOP 1 RouteEntryId  FROM POProcessQtyDetails WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RouteLineNo  AND IsActive=1)
	 BEGIN
	 INSERT INTO POProcessQtyDetails
									(
									POType,
									PrePOId,
									ItemId,
									RouteEntryId,
									RoutLineNo,
									TotalAccQty,
									AccQty,
									ReworkQty,
									RejQty,
									CreatedBy
									)
						 VALUES
								  (
								  @POType,
								  @PrePOId,
								  @ItemId,
								  @RouteEntryId,
								  @RouteLineNo,
								  cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float),
								  cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float),
								  cast(isnull(@ReworkQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float),
								  cast(isnull(@RejQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float),
								  @CreatedBy
								  )
   END
   ELSE
   BEGIN 
       UPDATE POProcessQtyDetails SET AccQty=CAST(ISNULL(AccQty,'0')  AS FLOAT) + (cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float)),
									  TotalAccQty=CAST(ISNULL(TotalAccQty,'0')  AS FLOAT) + (cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float)),
									  ReworkQty=CAST(ISNULL(ReworkQty,'0')  AS FLOAT) + (cast(isnull(@ReworkQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float)),
									  RejQty=CAST(ISNULL(RejQty,'0')  AS FLOAT) + (cast(isnull(@RejQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float))
	   WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RouteLineNo AND IsActive=1 
      
   END

    IF @POType='CustomerPO'
	BEGIN
		  Update S set S.Status='In Progress' from PrePoSub S
		  where S.PrePOId=@PrePOId and S.ItemId=@ItemId

		  Update M set M.Status='In Progress' from PrePOMain M
		  where M.PrePOId=@PrePOId;
	END
	ELSE
	BEGIN
		Update S set S.Status='In Progress' from JobOrderPOSub S
		where S.JobOrderPOId=@PrePOId and S.JobOrderPOSubId=@ItemId;

		Update M set M.Status='In Progress' from JobOrderPOMain M
		where  M.JobOrderPOId=@PrePOId;
	END 

   	SET @FinalRoutLineNo =(SELECT TOP 1 RoutLineNo FROM RouteCardEntry R where R.IsActive=1 and RouteEntryId=@RouteEntryId order by RoutLineNo desc);
	set @FinalProcessProdQty=(SELECT TOP 1 AccQty FROM POProcessQtyDetails P WHERE P.IsActive=1 AND P.RouteEntryId=@RouteEntryId AND RoutLineNo=@FinalRoutLineNo);
	IF @POType='CustomerPO'
	BEGIN
	    UPDATE PrePOSub  SET Status='Closed' , ClosedOn=getDate()
		WHERE PrePOId=@PrePOId and ItemId=@ItemId AND ISACTIVE=1  and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE PM  SET Status='Closed' , ClosedOn=getDate() 
		FROM PrePOMain PM
		INNER JOIN (
				SELECT 	COUNT(CASE when PS.Status='Closed' then 1 else null end ) as ClosedCount, Count(PS.ItemId) as TotalCount
				FROM PrePOSub PS
				WHERE PS.IsActive=1 and PS.PrePOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount 
	     IF @RouteLineNo=@FinalRoutLineNo
		 BEGIN
		      IF EXISTS(SELECT TOP 1 ItemId FROM ItemStock WHERE ItemId=@ItemId and IsActive=1 )
			  BEGIN
			     UPDATE ItemStock SET Qty = CAST(ISNULL(QTY,'0') AS decimal(18,2)) + (cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float))
				 WHERE ItemId=@ItemId and IsActive=1 
			  END
			  ELSE
			  BEGIN
				   INSERT INTO ItemStock
									(
									ItemId,
									Qty,
									CreatedBy
									)
						VALUES
								  (
								  @ItemId,
								  cast(isnull(@AccQty ,'0') as float) * CAST(isnull(@ConvFactor,'1') as float),
								  @CreatedBy
								  )
			      
			  END
		 END
	END
	ELSE
	BEGIN
	    UPDATE JobOrderPOSub  SET Status='Closed' , ClosedOn=getDate()
		WHERE JobOrderPOId=@PrePOId and JobOrderPOSubId=@ItemId AND ISACTIVE=1  and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE JM  SET Status='Closed' , ClosedOn=getDate() 
		FROM JobOrderPOMain JM
		INNER JOIN (
				SELECT 	COUNT(CASE when JS.Status='Closed' then 1 else null end ) as ClosedCount, Count(JS.JobOrderPOSubId) as TotalCount
				FROM JobOrderPOSub JS
				WHERE JS.IsActive=1 and JS.JobOrderPOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount  
	END
					SELECT '1'

END

ELSE IF @Action = 'GetManualProductionDtls'
BEGIN
set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;
     select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by            
							 case when @Sortcol=0 then A.ManualProdEntryId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.Date	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.PrePONo end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.PrePONo end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.CustomerName end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.CustomerName end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.PartNo_Description	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.PartNo_Description end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.RoutCardNo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.RoutCardNo end desc,
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.Operation end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.Operation end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.AccQty end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.AccQty end desc,
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.ReworkQty end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.ReworkQty end desc					    
                     ) as RowNum  
					 from (
								select  MP.ManualProdEntryId, MP.Date, MP.POType, MP.PrePOId, MP.ItemId, MP.RouteEntryId, MP.RouteLineNo,
								MP.AccQty, MP.RejQty, MP.ReworkQty, 
								ISNULL(PM.PrePONo,JM.PONo) as PrePONo,RC.RoutLineNo, RC.OperationId, RC.RoutCardNo,
								'P'+cast(RC.RoutLineNo as varchar)+ ' - ' + O.OperationName as Operation, 
								case when MP.POType ='CustomerPO' then I.PartNo +'-' + I.Description else JS.PartNo +'-'+JS.ItemName end as PartNo_Description,
								CM.CustomerName ,
								RC.ProcessQty, COUNT(*) over() as TotalCount from ManualProductionEntry MP
								left join PrePOMain PM on MP.POType='CustomerPO' and  PM.PrePOId = MP.PrePOId and PM.IsActive=1 
								left join ItemMaster I on MP.POType='CustomerPO' and  I.itemId = MP.itemId and I.IsActive = 1
								left join JobOrderPOMain JM on MP.POType='JobOrderPO' and  JM.JobOrderPOId = MP.PrePOId and JM.IsActive=1 
								left join JobOrderPOSub JS on MP.POType='JobOrderPO' and  JS.JobOrderPOSubId = MP.itemId and JS.IsActive = 1
								inner join CustomerMaster CM on CM.CustomerId=case when MP.POType='CustomerPO' then PM.CustId else JM.CustomerId end  and CM.IsActive=1
								inner join RouteCardEntry RC on RC.RouteEntryId = MP.RouteEntryId and RC.RoutLineNo = MP.RoutelineNo and RC.IsActive = 1
								inner join OperationMaster O on O.OperationId = RC.OperationId and O.IsActive=1 							
								where MP.IsActive = 1 and cast(MP.Date as date) between  cast(@FromDate as date) and cast(@ToDate as date)
						  )A 
						  where (@SearchString is null or A.Date like '%' +@SearchString+ '%' or A.CustomerName like '%' +@SearchString+ '%' or
						  A.PrePONo like '%' +@SearchString+ '%' or A.PartNo_Description like '%' +@SearchString+ '%' or A.RoutCardNo like '%' +@SearchString+ '%' or
						  A.Operation like '%' + @SearchString+ '%' or A.AccQty like '%' +@SearchString+ '%' or  A.ReworkQty like '%' +@SearchString+ '%' )
			            ) A where  RowNum > @FirstRec and RowNum <= @LastRec 

	
END
ELSE IF @Action = 'GetManualProductionbyId'
BEGIN
	select MP.ManualProdEntryId, MP.Date, MP.POType, MP.PrePOId, MP.ItemId, MP.RouteEntryId, MP.RouteLineNo,
	MP.AccQty, MP.RejQty, MP.ReworkQty, PM.PrePONo, RC.RoutLineNo, RC.OperationId,
	'P'+cast(RC.RoutLineNo as varchar)+ ' - ' + O.OperationName as Operation, I.PartNo +'-' + I.Description as PartNo_Description,
	RC.ProcessQty from ManualProductionEntry MP
	inner join PrePOMain PM on PM.PrePOId = MP.PrePOId and PM.IsActive=1
	inner join RouteCardEntry RC on RC.RouteEntryId = MP.RouteEntryId and RC.IsActive = 1
	inner join OperationMaster O on O.OperationId = RC.OperationId and O.IsActive=1 
	inner join ItemMaster I on I.itemId = MP.itemId and I.IsActive = 1
	where MP.IsActive = 1 and ManualProdEntryId = @ManualProdEntryId
END
ELSE IF @Action='MoveEndBitStkToPOProcess'
BEGIN
     UPDATE RMMidStock SET Qty=CAST(ISNULL(QTY,'0') AS decimal(18,3)) - CAST(ISNULL(@AccQty,'0') AS DECIMAL(18,2))
	 WHERE RawMaterialId=@RawMaterialId and Text1=@Text1 and Text2=@Text2 and Text3=@Text3 and
	 Value1=@Value1 and isnull(Value2,'')=isnull(@Value2,'') and Value3=@Value3 and OperationId=@OperationId;

	 SET @ManualProdEntryId=ISNULL((SELECT TOP 1 ManualProdEntryId+1 FROM ManualProductionEntry ORDER BY ManualProdEntryId DESC),1);	 
	 INSERT INTO ManualProductionEntry
									 (
									 ManualProdEntryId,
									 Date,
									 POType,
									 PrePOId,
									 ItemId,
									 RouteEntryId,
									 RoutelineNo,
									 AccQty,
									 RejQty,
									 ReworkQty,
									 CreatedBy
									 )
						VALUES
									(
									@ManualProdEntryId,
									@Date,
									'CustomerPO',
									@PrePOId,
									@ItemId,
									@RouteEntryId,
									@RouteLineNo,
									@AccQty,
									'0',
									'0',
									@CreatedBy
									)
     IF NOT EXISTS(SELECT TOP 1 RouteEntryId  FROM POProcessQtyDetails WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RouteLineNo  AND IsActive=1)
	 BEGIN
	 INSERT INTO POProcessQtyDetails
									(
									POType,
									PrePOId,
									ItemId,
									RouteEntryId,
									RoutLineNo,
									TotalAccQty,
									AccQty,
									ReworkQty,
									RejQty,
									CreatedBy
									)
						 VALUES
								  (
								  @POType,
								  @PrePOId,
								  @ItemId,
								  @RouteEntryId,
								  @RouteLineNo,
								  cast(isnull(@AccQty ,'0') as float),
								  cast(isnull(@AccQty ,'0') as float),
								  cast(isnull(@ReworkQty ,'0') as float),
								  cast(isnull(@RejQty ,'0') as float),
								  @CreatedBy
								  )
   END
   ELSE
   BEGIN 
       UPDATE POProcessQtyDetails SET AccQty=CAST(ISNULL(AccQty,'0')  AS FLOAT) + cast(isnull(@AccQty ,'0') as float) ,
									  TotalAccQty=CAST(ISNULL(TotalAccQty,'0')  AS FLOAT) + cast(isnull(@AccQty ,'0') as float),
									  ReworkQty=CAST(ISNULL(ReworkQty,'0')  AS FLOAT) + cast(isnull(@ReworkQty ,'0') as float) ,
									  RejQty=CAST(ISNULL(RejQty,'0')  AS FLOAT) + cast(isnull(@RejQty ,'0') as float) 
	   WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=@RouteLineNo AND IsActive=1 
      
   END

     IF @POType='CustomerPO'
	BEGIN
		  Update S set S.Status='In Progress' from PrePoSub S
		  where S.PrePOId=@PrePOId and S.ItemId=@ItemId

		  Update M set M.Status='In Progress' from PrePOMain M
		  where M.PrePOId=@PrePOId;
	END
	ELSE
	BEGIN
		Update S set S.Status='In Progress' from JobOrderPOSub S
		where S.JobOrderPOId=@PrePOId and S.JobOrderPOSubId=@ItemId;

		Update M set M.Status='In Progress' from JobOrderPOMain M
		where  M.JobOrderPOId=@PrePOId;
	END 

   	SET @FinalRoutLineNo =(SELECT TOP 1 RoutLineNo FROM RouteCardEntry R where R.IsActive=1 and RouteEntryId=@RouteEntryId order by RoutLineNo desc);
	set @FinalProcessProdQty=(SELECT TOP 1 AccQty FROM POProcessQtyDetails P WHERE P.IsActive=1 AND P.RouteEntryId=@RouteEntryId AND RoutLineNo=@FinalRoutLineNo);
	
	 UPDATE PrePOSub  SET Status='Closed' , ClosedOn=getDate()
	 WHERE PrePOId=@PrePOId and ItemId=@ItemId AND ISACTIVE=1  and CAST(isnull(@FinalProcessProdQty,'0') as float) >=CAST(isnull(Qty,'0') as float);

		UPDATE PM  SET Status='Closed' , ClosedOn=getDate() 
		FROM PrePOMain PM
		INNER JOIN (
				SELECT 	COUNT(CASE when PS.Status='Closed' then 1 else null end ) as ClosedCount, Count(PS.ItemId) as TotalCount
				FROM PrePOSub PS
				WHERE PS.IsActive=1 and PS.PrePOId= @PrePOId 
			  )A on A.ClosedCount=A.TotalCount 
	     IF @RouteLineNo=@FinalRoutLineNo
		 BEGIN
		      IF EXISTS(SELECT TOP 1 ItemId FROM ItemStock WHERE ItemId=@ItemId and IsActive=1 )
			  BEGIN
			     UPDATE ItemStock SET Qty = CAST(ISNULL(QTY,'0') AS decimal(18,2)) + cast(isnull(@AccQty ,'0') as float)
				 WHERE ItemId=@ItemId and IsActive=1 
			  END
			  ELSE
			  BEGIN
				   INSERT INTO ItemStock
									(
									ItemId,
									Qty,
									CreatedBy
									)
						VALUES
								  (
								  @ItemId,
								  cast(isnull(@AccQty ,'0') as float),
								  @CreatedBy
								  )
			      
			  END
		 END
	Select '1'
	
END
						
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[MaterialIssueSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MaterialIssueSP]
								(
								@Action varchar(75)=null,
								@MaterialIssueId int=0,
								@Date varchar(20)=null,
								@PrePOId int =0,
								@ItemId int=0,
								@RawMaterialId int =0,
								@RMDimensionId int=0,
								@IssueQtyNos varchar(20)=null,
								@IssueQtyKgs varchar(20)=null,
								@CreatedBy int =0,
								@RouteEntryId int =0,
								@SearchString varchar(200)=NULL,
								@FirstRec INT =0,
								@LastRec INT =0,
								@DisplayStart INT =0,
								@DisplayLength INT =0,
								@Sortcol INT =0,
								@SortDir varchar(10)=null
								)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertMaterialIssue'
BEGIN
    ---If Edit is done in future , Please make sure that the stocks are correctly maintained
     SET @MaterialIssueId =ISNULL((SELECT TOP 1 MaterialIssueId+1 FROM MaterialIssue ORDER BY MaterialIssueId DESC),1);
	 INSERT INTO MaterialIssue
							 (
							 MaterialIssueId,
							 Date,
							 PrePOId,
							 ItemId,
							 RawMaterialId,
							 RMDimensionId,
							 IssueQtyNos,
							 IssueQtyKgs,
							 CreatedBy
							 )
						VALUES
							 (
							 @MaterialIssueId,
							 @Date,
							 @PrePOId,
							 @ItemId,
							 @RawMaterialId,
							 @RMDimensionId,
							 @IssueQtyNos,
							 @IssueQtyKgs,
							 @CreatedBy
							 )
		UPDATE RMDimensionWiseStock SET QtyNos=CAST(ISNULL(QtyNos,'0') AS decimal(18,2)) -CAST(ISNULL(@IssueQtyNos,'0') AS decimal(18,2)) ,
										QtyKgs=CAST(ISNULL(QtyKgs,'0') AS decimal(18,2)) -CAST(ISNULL(@IssueQtyKgs,'0') AS decimal(18,2)) 
		WHERE RMDimensionId=@RMDimensionId AND VendorId=0 AND IsActive=1;

		Select top 1  @RouteEntryId=RouteEntryId from RouteCardEntry RC
		where RC.IsActive=1 and RC.PrePOId=@PrePOId and RC.ItemId=@ItemId ;

	IF NOT EXISTS(SELECT TOP 1 RouteEntryId  FROM POProcessQtyDetails WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=0  AND IsActive=1)
	 BEGIN
	 INSERT INTO POProcessQtyDetails
									(
									POType,
									PrePOId,
									ItemId,
									RouteEntryId,
									RoutLineNo,
									TotalAccQty,
									AccQty,
									ReworkQty,
									RejQty,
									CreatedBy
									)
						 VALUES
								  (
								  'CustomerPO',
								  @PrePOId,
								  @ItemId,
								  @RouteEntryId,
								  0,
								  cast(isnull(@IssueQtyNos ,'0') as float),
								  cast(isnull(@IssueQtyNos ,'0') as float),
								  '0',
								  '0',
								  @CreatedBy
								  )
	   END
	   ELSE
	   BEGIN 
		   UPDATE POProcessQtyDetails SET AccQty=CAST(ISNULL(AccQty,'0')  AS FLOAT) + (cast(isnull(@IssueQtyNos ,'0') as float)),
										  TotalAccQty=CAST(ISNULL(TotalAccQty,'0')  AS FLOAT) + (cast(isnull(@IssueQtyNos ,'0') as float))
		   WHERE RouteEntryId=@RouteEntryId AND RoutLineNo=0 AND IsActive=1 
      
	   END
	  
	
		  Update S set S.Status='In Progress' from PrePoSub S
		  where S.PrePOId=@PrePOId and S.ItemId=@ItemId

		  Update M set M.Status='In Progress' from PrePOMain M
		  where M.PrePOId=@PrePOId;
	
				SELECT '1'
END
ELSE IF @Action='GetMaterialIssue'
BEGIN
set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;
        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by          
							 case when @Sortcol=0 then A.MaterialIssueId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.Date	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.PrePONo end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.PrePONo end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.ItemPartNo_Desc end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.ItemPartNo_Desc end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.RMCode_Desc end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.RMCode_Desc end desc,							 
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.Dimension end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.Dimension end desc,							 
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.IssueQtyNos end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.IssueQtyNos end desc	    
                     ) as RowNum  
					 from (

							Select MI.MaterialIssueId, MI.Date,PM.PrePONo,I.PartNo +' - '+ I.Description as ItemPartNo_Desc , R.CodeNo+' - '+ R.Description as RMCode_Desc,	 
							RW.Text1 +'-' + RW.Value1 + case when RW.Text2 <>'' or RW.Text2 is not  null then ' * ' + RW.Text2+ '-'+RW.Value2 +' * ' else ' * ' end +RW.Text3 +'-' +RW.Value3 as Dimension,
							MI.IssueQtyNos, COUNT(*) over() as TotalCount
							from MaterialIssue MI
							inner join PrePOMain PM on PM.PrePOId =MI.PrePOId and PM.IsActive=1
							inner join ItemMaster I on I.ItemId=MI.ItemId and I.IsActive=1 
							inner join RawMaterial R on R.RawMaterialId=MI.RawMaterialId and R.IsActive=1 
							inner join RMDimensionWiseStock RW on RW.RMDimensionId=MI.RMDimensionId and RW.IsActive=1
							where MI.IsActive=1
						)A 
						where (@SearchString is null or A.Date like '%' +@SearchString+ '%' or
						A.PrePONo like '%' +@SearchString+ '%' or A.ItemPartNo_Desc like '%' +@SearchString+ '%' or
						A.RMCode_Desc like '%' + @SearchString+ '%' or A.Dimension like '%' + @SearchString + '%' or
						A.IssueQtyNos like '%' + @SearchString + '%')
						) A where  RowNum > @FirstRec and RowNum <= @LastRec
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[MaterialOutDCSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MaterialOutDCSP]
								(
								@Action varchar(75)=null,
								@MaterialOutDCId int =0,
								@MaterialOutDCNo varchar(20)=null,
								@MaterialOutDCType varchar(30)=null,
								@CustomerId int =0,
								@Date varchar(20)=null,
								@NatureOfProcess varchar(200)=null,
								@Types varchar(30)=null,
								@DeliverySchedule varchar(100)=null,
								@VehicleNo varchar(30)=null,
								@AppxValue varchar(50)=null,
								@DrawingEnclosed varchar(10)=null,
								@Remarks varchar(max)=null,
								@AsstYear varchar(20)=null,
								@IsApproved bit=0,
								@CreatedBy int =0,
								@Year varchar(20)=null,
								@MaterialOutDCSub MaterialOutDCSub readonly,
								   @SearchString VARCHAR(200)=NULL,
								   @FirstRec INT =0,
								   @LastRec INT =0,
								   @DisplayStart INT =0,
								   @DisplayLength INT =0,
								   @Sortcol INT =0,
								   @SortDir varchar(10)=null,							   
								   @FromDate varchar(20)=null,								   
								   @ToDate varchar(20)=null,
								   @ConvFactor varchar(20)=null,@ViewKey varchar(20)=null
								)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertMaterialOutDC'
BEGIN
   IF @MaterialOutDCId=0
   BEGIN
        SET @MaterialOutDCId=ISNULL((SELECT TOP 1 MaterialOutDCId+1 FROM MaterialOutDCMain ORDER BY MaterialOutDCId DESC),1);
		SET @MaterialOutDCNo=( select format + ' ' + cast(CurrentNumber as varchar)  from SerialNoFormats where type='DC' and year=@Year)
        update SerialNoFormats set CurrentNumber=CurrentNumber+1 where type='DC' and year=@Year;
		SET @IsApproved='1';
   END
   ELSE
   BEGIN
        Update WS SET WS.Qty=cast(isnull(WS.Qty,'0') as decimal(18,2)) + cast(isnull(MS.Qty,'0') as decimal(18,2))
		from Wear_DamagedItemStock WS
		inner join MaterialOutDCSub MS on MS.Type=WS.Status and MS.ItemId=WS.ItemId AND MS.MaterialOutDCID=@MaterialOutDCId AND MS.IsActive=1
		where WS.IsActive=1 ;

		UPDATE JS SET JS.ReworkBalQty=cast(isnull(JS.ReworkBalQty,'0') as decimal(18,2)) + cast(isnull(MS.Qty,'0') as decimal(18,2)),
					  JS.OutQty=cast(isnull(JS.OutQty,'0') as decimal(18,2)) - cast(isnull(MS.Qty,'0') as decimal(18,2))
		FROM JobWorkInspection JS
		inner join MaterialOutDCSub MS ON MS.Type='Rework' and MS.QCId=JS.JWId AND MS.MaterialOutDCID=@MaterialOutDCId AND MS.IsActive=1
		WHERE JS.IsActive=1

        Update MaterialOutDCMain set IsActive=0 where MaterialOutDCID=@MaterialOutDCId;
        Update MaterialOutDCSub set IsActive=0 where MaterialOutDCID=@MaterialOutDCId;        
   END
      INSERT INTO MaterialOutDCMain
								   (
								   MaterialOutDCId,
								   MaterialOutDCNo,
								   MaterialOutDCType,
								   CustomerId,
								   Date,
								   NatureOfProcess,
								   Types,
								   DeliverySchedule,
								   VehicleNo,
								   AppxValue,
								   DrawingEnclosed,
								   Remarks,
								   AsstYear,
								   IsApproved,
								   CreatedBy
								   )
						VALUES
								(
								@MaterialOutDCId,
								@MaterialOutDCNo,
								@MaterialOutDCType,
								@CustomerId,
								@Date,
								@NatureOfProcess,
								@Types,
								@DeliverySchedule,
								@VehicleNo,
								@AppxValue,
								@DrawingEnclosed,
								@Remarks,
								cast(year(cast(@date as date)) as varchar) + '-' +cast( YEAR(cast(@date as date))+1 as varchar),
								@IsApproved,
								@CreatedBy
								)
	  INSERT INTO MaterialOutDCSub
							        (
									MaterialOutDCId,
									MaterialOutDCSubId,
									Type,
									ItemId,
									QCId,
									RMId,
									ItemDescription,
									Process,
									Qty,
									InwardBalQty,
									UOM,
									Remarks,
									CreatedBy
									)
						SELECT 
								   @MaterialOutDCId,
								   ROW_NUMBER() OVER(ORDER BY (SELECT 1)),
								   Type,
								   ItemId,
								   QCId,
								   RMId,
								   ItemDescription,
								   Process,
								   Qty,
								   Qty,
								   UOM,
								   Remarks,
								   @CreatedBy FROM @MaterialOutDCSub;
		Update WS SET WS.Qty=cast(isnull(WS.Qty,'0') as decimal(18,2)) - cast(isnull(MS.Qty,'0') as decimal(18,2))
		from Wear_DamagedItemStock WS
		inner join @MaterialOutDCSub MS on MS.Type=WS.Status and MS.ItemId=WS.ItemId
		where WS.IsActive=1 ;

		UPDATE JS SET JS.ReworkBalQty=cast(isnull(JS.ReworkBalQty,'0') as decimal(18,2)) - cast(isnull(MS.Qty,'0') as decimal(18,2)),
					  JS.OutQty=cast(isnull(JS.OutQty,'0') as decimal(18,2)) + cast(isnull(MS.Qty,'0') as decimal(18,2))
		FROM JobWorkInspection JS
		inner join @MaterialOutDCSub MS ON MS.Type='Rework' and MS.QCId=JS.JWId 
		WHERE JS.IsActive=1
			SELECT '1'
END
ELSE IF @Action='GetMaterialOutDCDtls'
BEGIN
set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;


	Select * into  #MaterialOutInwardMain from  (	Select distinct MI.DCId from MaterialOutInwardMain MI where MI.IsActive=1 )A

     select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by            
							 case when @Sortcol=0 then A.MaterialOutDCId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.MaterialOutDCNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.MaterialOutDCNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Date end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Date end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.CustomerName end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.CustomerName end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.NatureOfProcess	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.NatureOfProcess end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.VehicleNo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.VehicleNo end desc,
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.DeliverySchedule end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.DeliverySchedule end desc			    
                     ) as RowNum  
					 from (
								Select MM.MaterialOutDCId, MM.MaterialOutDCNo,MM.Date,C.CustomerName, MM.NatureOfProcess, MM.VehicleNo,
								 MM.DeliverySchedule,case when MI.DCId is null then 'false' else 'true' end as InwardStatus,
								 COUNT(*) over() as TotalCount
								 from MaterialOutDCMain MM
								 left join #MaterialOutInwardMain MI on MI.DCId=MM.MaterialOutDCId
								inner join CustomerMaster C on C.CustomerId=MM.CustomerId and C.IsActive=1 
								where MM.IsActive=1 AND MM.MaterialOutDCType=@MaterialOutDCType 
								and (@ViewKey='View' or MM.IsApproved=0)
						  )A 
						  where (@SearchString is null or A.MaterialOutDCNo like '%' +@SearchString+ '%' or A.Date like '%' +@SearchString+ '%' or
						  A.CustomerName like '%' +@SearchString+ '%' or A.NatureOfProcess like '%' +@SearchString+ '%' or A.VehicleNo like '%' +@SearchString+ '%' or
						  A.DeliverySchedule like '%' + @SearchString+ '%' )
			            ) A where  RowNum > @FirstRec and RowNum <= @LastRec 	
END
ELSE IF @Action='GetMaterialOutDCDtlsById'
BEGIN
     Select MM.MaterialOutDCId,MM.MaterialOutDCNo,MM.MaterialOutDCType,MM.CustomerId,
	 MM.Date, MM.NatureOFProcess,MM.Types, MM.DeliverySchedule,MM.VehicleNo,MM.AppxValue,MM.DrawingEnclosed,MM.Remarks,MM.AsstYear
	 from MaterialOutDCMain MM
	 where  MM.MaterialOutDCId=@MaterialOutDCId and  MM.IsActive=1 

	 Select MS.Type, MS.ItemId,MS.QCId,MS.RMId,MS.ItemDescription,MS.Process,MS.Qty,MS.UOM, U.UnitName,MS.Remarks from MaterialOutDCSub MS
	 inner join UnitMaster U on U.UnitId=MS.UOM and U.IsActive=1 
	 where MS.MaterialOutDCId=@MaterialOutDCId and MS.IsActive=1 
END
ELSE IF @Action='GetItemDtlsForMaterialOutDC'
BEGIN
    Select WS.ItemId,I.Description, WS.Status,cast(isnull(WS.Qty,'0') as decimal(18,2)) + cast(isnull(MS.Qty,'0') as decimal(18,2)) as Qty  from Wear_DamagedItemStock WS
	inner join ItemMaster I on I.ItemId=WS.ItemId and I.IsActive=1 
	left join MaterialOutDCSub MS on MS.MaterialOutDCId=@MaterialOutDCId and  MS.Type=WS.Status and MS.IsActive=1
	where WS.IsActive=1  and cast(isnull(WS.Qty,'0') as decimal(18,2)) + cast(isnull(MS.Qty,'0') as decimal(18,2)) > cast('0' as decimal)

	Select J.JWId as QCId ,J.RawMaterialId,
	case when J.POType='CustomerPO' then RM.CodeNo +' - '+ RM.Description else JS.PartNo +' - ' + JS.ItemName end as Description,
	cast(isnull(J.ReworkBalQty,'0') as decimal(18,2)) + cast(isnull(MS.Qty,'0') as decimal(18,2)) as Qty
	from JobWorkInspection J 
	LEFT join RawMaterial RM on J.POType='CustomerPO' and  RM.RawMaterialId=J.RawMaterialId and RM.IsActive=1
	LEFT join JobOrderPOSub JS on J.POType='JobOrderPO' and  JS.JobOrderPOId=J.PrePOId and JS.JobOrderPOSubId=J.ItemId and JS.IsActive=1
	left join MaterialOutDCSub MS on MS.MaterialOutDCId=@MaterialOutDCId and  MS.Type='Rework' and MS.IsActive=1
	where J.IsActive=1 and cast(isnull(J.ReworkBalQty,'0') as decimal(18,2)) + cast(isnull(MS.Qty,'0') as decimal(18,2)) > cast('0' as decimal)
END
--ELSE IF @Action=''
--BEGIN
--  Select J.JWID,J.RawMaterialId ,RM.CodeNo +' - '+RM.Description as RawMaterial  from JobWorkInspection J
--  LEFT join RawMaterial RM on RM.RawMaterialId=J.RawMaterialId and RM.IsActive=1 
--  where J.IsActive=1  and CAST(ISNULL(J.ReworkQty,'0') as decimal(18,2)) - CAST(ISNULL(J.OutQty,'0') as decimal(18,2))>cast('0' as decimal)
--END

ELSE IF @Action='ApproveMaterialOutDc'
BEGIN
   UPDATE MaterialOutDCMain SET IsApproved=1 WHERE MaterialOutDCId=@MaterialOutDCId AND IsActive=1 ;
   Select 1
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[MaterialOutInwardSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MaterialOutInwardSP]
								    (
									@Action varchar(75)=null,
									@InwardId int =0,
									@InwardNo varchar(20)=null,
									@InwardDate varchar(20)=null,
									@CustomerId int =0,
									@DCId int =0,
									@RefNo varchar(20)=null,
									@RefDate varchar(20)=null,
									@Remarks varchar(max)=null,
									@CreatedBy int =0,
									@MaterialOutInwardSub MaterialOutInwardSub READONLY,
									@SearchString VARCHAR(200)=NULL,
									@FirstRec INT =0,
									@LastRec INT =0,
									@DisplayStart INT =0,
									@DisplayLength INT =0,
									@Sortcol INT =0,
									@SortDir varchar(10)=null,
									@RouteEntryId int=0
									)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertMaterialOutInward'
BEGIN
     IF @InwardId=0
	 BEGIN
	      SET @InwardId=ISNULL((SELECT TOP 1 InwardId+1 FROM MaterialOutInwardMain ORDER BY InwardId DESC),1);
		  SET @InwardNo=@InwardId;
	 END
	 ELSE
	 BEGIN
	   UPDATE MS SET MS.InwardBalQty = cast(ISNULL(MS.InwardBalQty,'0') as decimal(18,2)) + cast(ISNULL(MI.Qty,'0') as decimal(18,2))
	   from MaterialOutDCSub MS
	   INNER JOIN MaterialOutInwardSub MI on MI.InwardId=@InwardId and MS.MaterialOutDCId=MI.DCId and MI.MaterialOutDCSubId=MS.MaterialOutDCSubId and MI.IsActive=1
	   where MS.IsActive=1 ; 

	      Select * into #OMaterialOutInwardSub from (Select T.ItemId, sum (cast(isnull(T.qty,'0') as decimal(18,3))) as Qty from MaterialOutInwardSub T  
													where T.InwardId=@InwardId and  T.Type in ('Wear','Damaged') and T.IsActive=1  group by T.ItemId)A


		UPDATE I set I.Qty=cast(isnull(I.Qty,'0') as decimal(18,3))-cast(isnull(T.qty,'0') as decimal(18,3))
		FROM ItemStock I 
		inner join #OMaterialOutInwardSub T on  T.ItemId=I.ItemId 
		where I.IsActive=1 ;
		 
	    UPDATE MaterialOutInwardMain SET IsActive=0 WHERE InwardId=@InwardId;
	    UPDATE MaterialOutInwardSub SET IsActive=0 WHERE InwardId=@InwardId;
	 END
	    INSERT INTO MaterialOutInwardMain
										(
										InwardId,
										InwardNo,
										InwardDate,
										CustomerId,
										DCId,
										RefNo,
										RefDate,
										Remarks,
										CreatedBy
										)
							VALUES
									(
									@InwardId,
									@InwardNo,
									@InwardDate,
									@CustomerId,
									@DCId,
									@RefNo,
									@RefDate,
									@Remarks,
									@CreatedBy
									)
		INSERT INTO MaterialOutInwardSub
										(
										InwardId,
										DCId,
										MaterialOutDCSubId,
										Type,
										ItemId,
										QCId,
										RMId,
										Qty,
										InspectionStatus,
										CreatedBy
										)
								SELECT  @InwardId,
										@DCId,
										MaterialOutDCSubId,
										Type,
										ItemId,
										QCId,
										RMId,
										Qty,
										CASE WHEN TyPE IN ('Wear', 'Damaged') then 'true' else 'false' end,
										@CreatedBy FROM @MaterialOutInwardSub;

	   UPDATE MS SET MS.InwardBalQty = cast(ISNULL(MS.InwardBalQty,'0') as decimal(18,2))- cast(ISNULL(MI.Qty,'0') as decimal(18,2))
	   from MaterialOutDCSub MS
	   INNER JOIN @MaterialOutInwardSub MI on MS.MaterialOutDCId=@DCID and  MI.MaterialOutDCSubId=MS.MaterialOutDCSubId  
	   where MS.IsActive=1; 

	   Select * into #MaterialOutInwardSub from (Select T.ItemId, sum (cast(isnull(T.qty,'0') as decimal(18,3))) as Qty from @MaterialOutInwardSub T  where T.Type in ('Wear','Damaged') group by T.ItemId)A

		UPDATE I set I.Qty=cast(isnull(I.Qty,'0') as decimal(18,3))+cast(isnull(T.qty,'0') as decimal(18,3))
		FROM ItemStock I 
		inner join #MaterialOutInwardSub T on  T.ItemId=I.ItemId
		where I.IsActive=1 

									
				SELECT '1'
END
ELSE IF @Action='GetDCMainDtlsForInward'
BEGIN
       Set @DCId =(Select top 1 DCId from MaterialOutInwardMain where InwardId=@InwardId and IsActive=1);

	   Select DM.MaterialOutDCId, DM.MaterialOutDCNo,DM.Date,DM.NatureOfProcess from MaterialOutDCMain DM
	   inner join MaterialOutDCSub DS on DS.MaterialOutDCId=DM.MaterialOutDCId and DS.IsActive=1 and (DS.MaterialOutDCId=@DCId or cast(ISNULL(DS.InwardBalQty,'0') as decimal(18,3)) > CAST('0' AS DECIMAL) )
	   where DM.IsActive=1  and DM.CustomerId=@CustomerId and DM.IsApproved=1
       group by DM.MaterialOutDCId, DM.MaterialOutDCNo, DM.Date,DM.NatureOfProcess
END
ELSE IF @Action='GetDCSubDtlsForInward'
BEGIN
    SELECT DS.MaterialOutDCSubId,DS.Type,DS.ItemDescription,DS.Process,U.UnitName,DS.Remarks,DS.ItemId,DS.QCId,DS.RMId,DS.Qty as DCQty,
	cast(ISNULL(ID.Qty,'0') as decimal(18,2)) + cast(ISNULL(DS.InwardBalQty,'0') as decimal(18,2)) as PendingQty ,
	ID.Qty as ReceivedQty
	FROM MaterialOutDCSub DS
	INNER JOIN UnitMaster U ON U.UnitId = DS.UOM AND U.IsActive=1
	left join MaterialOutInwardSub ID on ID.InwardId=@InwardId and ID.IsActive=1 and ID.MaterialOutDCSubId=DS.MaterialOutDCSubId 
	WHERE DS.IsActive=1 and DS.MaterialOutDCId=@DCId AND  cast(ISNULL(ID.Qty,'0') as decimal(18,2)) + cast(ISNULL(DS.InwardBalQty,'0') as decimal(18,2))>CAST('0' AS decimal)
END
ELSE IF @Action='GetMaterialOuTInwardDtls'
BEGIN
     Set @FirstRec=@DisplayStart;
     Set @LastRec=@DisplayStart+@DisplayLength;

	     select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.InwardId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.InwardNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.InwardNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.CustomerName	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.CustomerName	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.InwardDate end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.InwardDate end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.MaterialOutDCNo	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.MaterialOutDCNo end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.DCDate end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.DCDate end desc				    
                     ) as RowNum  
					 from (								
						Select MI.InwardId,MI.InwardNo , C.CustomerName,MI.InwardDate,MD.MaterialOutDCNo, MD.Date as DCDate,
						COUNT(*) over() as TotalCount   from MaterialOutInwardMain MI
						inner join MaterialOutDCMain MD on MD.MaterialOutDCId =MI.DCId and MD.IsActive =1 
						inner join CustomerMaster C on C.CustomerId =MI.CustomerId and C.IsActive=1 
						where MI.IsActive=1 
						  )A where (@SearchString is null or A.InwardNo like '%' +@SearchString+ '%' or
									A.CustomerName like '%' +@SearchString+ '%' or A.InwardDate like '%' +@SearchString+ '%' or
									A.MaterialOutDCNo like '%' + @SearchString+ '%' or A.DCDate like '%' +@SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END

ELSE IF @Action='GetMaterialOutInWardDtlsById'
BEGIN
	Select M.InwardId, M.InwardNo,M.InwardDate,M.CustomerId,M.DCId,M.RefNo,M.RefDate,M.Remarks,D.DCDate,D.NatureOfProcess
	From MaterialOutInwardMain M
	Inner Join DCEntryMain D ON D.DCId = M.DCId AND D.IsActive=1
	WHERE M.InwardId=@InwardId AND M.IsActive=1
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[NewRMRequestSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[NewRMRequestSP]
                               (
							   @Action varchar(75)=null,
							   @RequestRMId int =0,
							   @PrePOId int =0,
							   @NewRMRequest NewRMRequest READONLY,
							   @CreatedBy int =0 ,
							   @Status VARCHAR(20)=NULL
							   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
 IF @Action='InsertNewRMRequest'
BEGIN
     SET @RequestRMId=ISNULL((SELECT TOP 1 RequestRMId FROM NewRMRequest ORDER BY RequestRMId DESC),0);
	 INSERT INTO NewRMRequest
						    (
							RequestRMId,
							PrePOId,
							MaterialId,
							Shape,
							Text1,
							Text2,
							Text3,
							Value1,
							Value2,
							Value3,
							CreatedBy
							)
		     SELECT 
						  @RequestRMId + ROW_NUMBER() OVER(ORDER BY (SELECT 1)),
						  @PrePOId,
						  MaterialId,
						  Shape,
						  Text1,
						  Text2,
						  Text3,
						  Value1,
						  Value2,
						  Value3,
						  @CreatedBy   FROM @NewRMRequest
						  
				SELECT '1'
END
ELSE IF @Action='GetNewRMRequestDtls'
BEGIN
     SELECT  NR.RequestRMId, NR.MaterialId,M.MaterialCode, M.materialName,NR.Shape,NR.Text1,NR.Text2,NR.Text3,NR.Value1,NR.Value2,NR.Value3,NR.Status,
	 NR.Value1 + case when NR.Text2 <>'' and NR.Text2 is not  null then ' * ' + NR.Value2  else '' end +
	  case when NR.Value3 <>'' and NR.Value3 is not  null then ' * ' + NR.Value3  else '' end as Dimension
	from NewRMRequest NR
	inner join MaterialMaster M on M.materialId=NR.MaterialId and M.isActive=1 
	where NR.IsActive=1 and (@Status is null or  NR.Status=@Status) and  @RequestRMId IN (0,NR.RequestRMId)
	order  by NR.RequestRMId desc
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH
							 

GO
/****** Object:  StoredProcedure [dbo].[OperationSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[OperationSP]
                           (
						   @Action varchar(50)=null,
						   @OperationId int =0,
						   @OperationCode varchar(20)=null,
						   @OperationName varchar(50)=null,
						   @CreatedBy int =0
						   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertOperation'
BEGIN
    IF @OperationId=0
	BEGIN
	   SET @OperationId=ISNULL((SELECT TOP 1 OperationId+1 FROM OperationMaster ORDER BY OperationId DESC),1)
	END
	ELSE
	BEGIN
	   UPDATE OperationMaster SET IsActive=0 WHERE OperationId=@OperationId;
	END
          INSERT INTO OperationMaster
		                            (
									OperationId,
									OperationCode,
									OperationName,
									CreatedBy
									)
						   VALUES
						           (
								   @OperationId,
								   @OperationCode,
								   @OperationName,
								   @CreatedBy
								   )
					select '1'
END
ELSE IF @Action='GetOperationDtls'
BEGIN
   SELECT OperationId, OperationCode,OperationName, OperationCode +'-' + OperationName as OperationCode_Name  FROM OperationMaster WHERE IsActive=1 ORDER BY OperationId DESC
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[PaymentTermsSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PaymentTermsSP]
	                        (
							@Action varchar(50)=null,
							@PaymentId int=0,
							@PaymentCode varchar(50)=null,
							@PaymentTerm varchar(75)=null,
							@CreatedBy int =0
							)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action ='InsertPaymentTerm'
BEGIN
     IF EXISTS(SELECT TOP 1 PaymentId FROM PaymentTerms WHERE PaymentId=@PaymentId)
	 BEGIN
	    UPDATE PaymentTerms SET IsActive=0 WHERE PaymentId=@PaymentId
	 END
	 ELSE
	 BEGIN
	      SET @PaymentId=isnull((Select top 1  PaymentId + 1 from PaymentTerms order  by id desc),1)
	 END
	 
	    INSERT INTO PaymentTerms
		                       (
							   PaymentId,
							   PaymentCode,
							   PaymentTerm,
							   CreatedBy
							   )
				values
							(
							@PaymentId,
							@PaymentCode,
							@PaymentTerm,
							@CreatedBy
							)
				
				   SELECT '1'

END 
ELSE IF @Action='GetPaymentTerms'
BEGIN
    SELECT PaymentId,PaymentCode,PaymentTerm   FROM PaymentTerms WHERE IsActive=1 ORDER BY PaymentId DESC
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[PetrolExpenseSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PetrolExpenseSP]
								(
								@Action varchar(75)=null,
								@PetrolExpenseId int =0,
								@VehicleId int=0,
								@CurrentKms varchar(20)=null,
								@Litre varchar(20)=null,
								@Amount varchar(20)=null,
								@OperatorId int =0,
								@AsOfDate varchar(20)=null,
								@Remarks varchar(max)=null,
								@CreatedBy int =0,
								@FromDate varchar(20)=null,
								@ToDate varchar(20)=null
								)
AS
BEGIN 
TRY
BEGIN TRANSACTION

IF @Action='InsertPetrolExpense'
BEGIN
   IF @PetrolExpenseId =0
   BEGIN
       SET @PetrolExpenseId=ISNULL((SELECT TOP 1 PetrolExpenseId+1 FROM PetrolExpenseDetails ORDER BY PetrolExpenseId DESC),1);
   END
   ELSE
   BEGIN
      UPDATE PetrolExpenseDetails SET IsActive=0 WHERE PetrolExpenseId=@PetrolExpenseId;
   END
      INSERT INTO PetrolExpenseDetails
									  (
									  PetrolExpenseId,
									  VehicleId,
									  CurrentKms,
									  Litre,
									  Amount,
									  OperatorId,
									  AsOfDate,
									  Remarks,
									  CreatedBy
									  )
							VALUES
									(
									  @PetrolExpenseId,
									  @VehicleId,
									  @CurrentKms,
									  @Litre,
									  @Amount,
									  @OperatorId,
									  @AsOfDate,
									  @Remarks,
									  @CreatedBy
									  )
					SELECT '1'
END
ELSE IF @Action='GetPetrolExpenseDtls'
BEGIN
      Select A.PetrolExpenseId,A.VehicleNo,A.VehicleName,A.CurrentKms,cast(A.CurrentKms as float)-CAST(A.LastUpdatedReading as float) as Diff,
	  A.AsOfDate,A.OperatorName,A.Amount from (
		Select PE.PetrolExpenseId,PE.vehicleId,V.VehicleNo,V.VehicleName, 
		PE.CurrentKms,PE.AsOfDate,PE.Amount, isnull(Lag(currentKms, 1) OVER(PARTITION BY PE.VehicleId ORDER BY cast(currentKms as float) asc),V.OpeningReading) AS LastUpdatedReading,
		PE.OperatorId,E.EmpName as OperatorName
		from PetrolExpenseDetails PE
		inner join VehicleMaster V on V.vehicleId =PE.vehicleId and V.isActive=1
		inner join EmployeeDetails E on E.EmpId=PE.OperatorId and E.IsActive=1 
		where PE.isActive=1
) A where CAST(A.AsOfDate as date) between CAST(@FromDate as date) and cast(@ToDate as date) and @OperatorId in (0,A.OperatorId)
	and @VehicleId in (0,A.VehicleId)
order by A.PetrolExpenseId desc
END
ELSE IF @Action='GetPetrolExpenseDtlsById'
BEGIN
  Select * from ( 
	   SELECT PE.PetrolExpenseId, PE.VehicleId,PE.CurrentKms,PE.Litre,PE.Amount,PE.OperatorId,PE.AsOfDate,PE.Remarks,
	   isnull(Lag(CurrentKms, 1) OVER(PARTITION BY PE.VehicleId ORDER BY cast(CurrentKms as float) asc),V.OpeningReading) AS LastUpdatedReading,
	   isnull(Lag(PE.AsOfDate, 1) OVER(PARTITION BY PE.VehicleId ORDER BY cast(currentKms as float) asc),V.OpeningReading) AS LastUpdatedOn,
	   Lag(CurrentKms, 1) OVER(PARTITION BY PE.VehicleId ORDER BY cast(CurrentKms as float) desc) as NextUpdatedReading
	   FROM PetrolExpenseDetails PE
	   inner join VehicleMaster V on V.vehicleId =PE.vehicleId and V.isActive=1
	   WHERE PE.IsActive=1 
   )A where A.PetrolExpenseId=@PetrolExpenseId
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[POGRNSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[POGRNSP]
					   (
					   @Action varchar(75)=null,
						@GRNId int =0,
						@GRNNo varchar(20)=null,
						@SupplierId int =0,
						@POIds varchar(max)=null,
						@GRNDate varchar(20)=null,
						@DCNo varchar(20)=null,
						@DCDate varchar(20)=null,
						@RefNo varchar(20)=null,
						@RefDate varchar(20)=null,
						@Remarks varchar(max)=null,
						@CreatedBy int =0,
						@POGRNSub POGRNSub readonly, 
						@SearchString VARCHAR(200)=NULL,
						@FirstRec INT =0,
						@LastRec INT =0,
						@DisplayStart INT =0,
						@DisplayLength INT =0,
						@Sortcol INT =0,
						@SortDir varchar(10)=null
					   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertPoGRN'
BEGIN
     IF @GrnId =0
	 BEGIN
	      SET @GrnId=isnull((select top 1 GRNId+1 from POGRNMain order  by GRNId desc),1);
		  SET @GrnNo=@GrnId;
	 END
	 ELSE
	 BEGIN
	       UPDATE PS SET PS.GrnBalQty = CAST(ISNULL(PS.GrnBalQty,'0') as decimal(18,3)) + cast(ISNULL(GS.RecQty,'0') as decimal(18,3))
		   from PurchaseOrderSub PS
		   INNER JOIN POGRNSub GS on GS.POId=PS.POId and GS.ItemId=PS.ItemId	  
		   where PS.IsActive=1 and  GS.GrnId=@GrnId and GS.IsActive=1;

			Select * into #OItemStk  from (Select T.ItemId,sum(cast(ISNULL(T.RecQty,'0') as decimal(18,3))) as Qty from POGRNSub T 
			where T.IsActive=1 and T.GRNId=@GRNId group by T.ItemId)A

		   Update I  Set I.Qty =cast(ISNULL(I.Qty,'0') as decimal(18,3))-cast(ISNULL(T.Qty,'0') as decimal(18,3))
		   from ItemStock I
		   inner join #OItemStk T on I.ItemId=T.ItemId 
		   where I.IsActive=1;

			UPDATE POGRNMain set IsActive=0 where grnId=@GrnId;
			UPDATE POGRNSub set IsActive=0 where grnId=@GrnId;
	 END
	     INSERT INTO [dbo].[POGRNMain]
						   (
						    [GRNId]
						   ,[GRNNo]
						   ,[GRNDate]
						   ,[SupplierId]
						   ,[POIds]
						   ,[DCNo]
						   ,[DCDate]
						   ,[RefNo]
						   ,[RefDate]
						   ,[Remarks]
						   ,[CreatedBy]
						   )
					VALUES
							(
							@GRNId,
							@GRNNo,
							@GRNDate,
							@SupplierId,
							@POIds, 
							@DCNO,
							@DCDate,
							@RefNo,
							@RefDate, 
							@Remarks,
							@CreatedBy
							)
			
		INSERT INTO [dbo].[POGRNSub]
				   ([GRNId]
				   ,[POId]
				   ,[ItemId]
				   ,[RecQty]
				   ,[CreatedBy]
				   )
			SELECT  
					@GrnId
					,[POId]
				   ,ItemId
				   ,[RecQty]
				   ,@CreatedBy from @POGRNSub;

	   UPDATE PS SET PS.GrnBalQty = cast(ISNULL(PS.GrnBalQty,'0') as decimal(18,3))- cast(ISNULL(GS.RecQty,'0') as decimal(18,3))
	   from PurchaseOrderSub PS
	   INNER JOIN @POGRNSub GS on GS.POId=PS.POId and GS.ItemId=PS.ItemId	  
	   where PS.IsActive=1 ;

	   Select * into #ItemStk  from (Select T.ItemId,sum( cast(ISNULL(T.RecQty,'0') as decimal(18,3))) as Qty from @POGRNSub T group by T.ItemId)A

	    
   Update I  Set I.Qty =cast(ISNULL(I.Qty,'0') as decimal(18,3))+ cast(ISNULL(T.Qty,'0') as decimal(18,3))
   from ItemStock I
   inner join #ItemStk T on I.ItemId=T.ItemId 
   where I.IsActive=1;

    INSERT INTO [dbo].ItemStock
						   (
						    ItemId
						   ,Qty
						   ,[CreatedBy]
		                  )
				 SELECT  T.ItemId,
						 T.Qty,
						 @CreatedBy  FROM #ItemStk T 
						  where not exists(Select ItemId from ItemStock I 
										   where I.ItemId=T.ItemId and I.ISActive=1)

		SELECT '1'

END
ELSE IF @Action='GetPOMainDtlsForGRN'
BEGIN
   SET @POIds =isnull((SELECT TOP 1 POIds FROM POGRNMain where IsActive=1 and GRNId=@GRNId),'');

    Select  PM.POId, PM.PONo from PurchaseOrderMain PM
	inner join PurchaseOrderSub PS on PS.POId = PM.POId and PS.IsActive=1  
	and (PS.POId in (Select value from fn_split(@POIds,',') where value<>'') or  cast(ISNULL(PS.GrnBalQty,'0') as decimal(18,3)) > CAST('0' AS DECIMAL) )
	where PM.IsActive=1 and PM.SupplierId=@SupplierId and PM.IsApproved=1 
	group by PM.POId, PM.PONo ;
END
ELSE IF @Action='GetPOSubDtlsForGRN'
BEGIN
    Select PS.POId, PM.PONo,PS.ItemId, I.PartNo +' - ' + I.Description as Item ,
	cast(ISNULL(GS.RecQty,'0') as decimal(18,3)) + cast(ISNULL(PS.GrnBalQty,'0') as decimal(18,3)) as Qty ,
	GS.RecQty,   U.UnitName  from PurchaseOrderSub PS	
	left join POGRNSub GS on GS.GRNId=@GrnId and GS.IsActive=1 and GS.POId=PS.POId and GS.ItemId=PS.ItemId
	INNER JOIN ItemMaster I ON I.ItemId = PS.ItemId AND I.IsActive=1
	INNER JOIN UnitMaster U ON U.UnitId = I.UOMId AND U.IsActive=1
	inner join PurchaseOrderMain PM on PM.POId=PS.POId and PM.IsActive=1 
	where PS.IsActive=1 and PS.POId in (Select value from fn_split(@POIds,',') where value<>'') and  
	cast(ISNULL(GS.RecQty,'0') as decimal(18,3)) + cast(ISNULL(PS.GrnBalQty,'0') as decimal(18,3)) > CAST('0' AS DECIMAL) 
END
ELSE IF @Action='GetPOGRNDtls'
BEGIN
         set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;


        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.GrnId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.GrnNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.GrnNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.GRNDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.GRNDate	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Supplier end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.PONos	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.PONos end desc			    
                     ) as RowNum  
					 from (								
						Select GM.GrnId, GM.GRNNo, GM.GRNDate,C.CustomerName as Supplier , 
						(Select PONo + ',' from PurchaseOrderMain PM where PM.IsActive=1 and PM.POId in (Select value from fn_split(GM.POIds,',') where value <>'') for xml path('')) as PONos,
						COUNT(*) over() as TotalCount 
						 from POGRNMain GM
						inner join CustomerMaster C on C.CustomerId=GM.SupplierId and C.IsActive=1 
						where GM.IsActive=1
						  )A where (@SearchString is null or A.GRNNo like '%' +@SearchString+ '%' or
									A.GRNDate like '%' +@SearchString+ '%' or A.Supplier like '%' +@SearchString+ '%' or
									A.PONos like '%' + @SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec
END
ELSE IF @Action='GetPOGrnMainDtlsById'
BEGIN
    SELECT GM.GrnId, GM.GrnNo ,GM.GRNDate, GM.SupplierId, GM.POIds, GM.RefNo, GM.RefDate,GM.DCNo, GM.DCDate, GM.Remarks FROM POGrnMain GM
	where GM.IsActive=1 and GM.GRNId=@GrnId
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[PrePOSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PrePOSP]
                       (
					   @Action varchar(75) = null,
					   @PrePOId int =0,
					   @InternalPONo varchar(20)=null,
					   @PrePONo varchar(100)=null,
					   @InternalPODate varchar(20)=null,
					   @Status varchar(20)=null,
					   @CustId int =0,
					   @CreatedBy int =0,
					   @PrePOSub PrePOSub readonly, 
					   @SearchString VARCHAR(200)=NULL,
					   @FirstRec INT =0,
					   @LastRec INT =0,
					   @DisplayStart INT =0,
					   @DisplayLength INT =0,
					   @Sortcol INT =0,
					   @SortDir varchar(10)=null

					   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
If @Action ='InsertPrePO'
BEGIN
    IF @PrePOId=0
	BEGIN
	   SET @PrePOId =ISNULL((SELECT TOP 1 PrePOId +1 FROM PrePOMain  ORDER BY PrePOId DESC),1);
	   SET @InternalPONo=@PrePOId;
	END
	ELSE
	BEGIN
	   UPDATE PrePOMain SET IsActive=0 where PrePOId=@PrePOId;
	   UPDATE PrePOSub SET IsActive=0 where PrePOId=@PrePOId;
	END
	    INSERT INTO PrePOMain
							 ( 
							 PrePOId,
							 InternalPONo ,
							 PrePONo,
							 InternalPODate,
							 CustId,
							 Status,
							 CreatedBy
							 )
					VALUES
					      (
						  @PrePOId,
						  @InternalPONo,
						  @PrePONo,
						  @InternalPODate,
						  @CustId,
						  @Status,
						  @CreatedBy
						  )
	INSERT INTO PrePOSub
					     (
						  PrePOId,
						  ItemId,
						  Qty,
						  InvoiceBalQty,
						  Status,
						  DeliveryStatus,
						  CreatedBy
						  )
				Select 
				         @PrePOId,
						 ItemId,
						 Qty,
						 Qty,
						 Status,
						 DeliveryStatus,
						 @CreatedBy  from @PrePOSub;
			SELECT '1'  	   
END
ELSE IF @Action='GetPrePODtlsById'
BEGIN
    SELECT PM.PrePOId,PM.InternalPONo , PM.PrePONo, PM.InternalPODate, PM.CustId, PM.Status , C.CustomerName FROM PrePOMain PM
	inner join CustomerMaster C on C.CustomerId=PM.CustId and C.IsActive=1 
	 WHERE PM.IsActive=1 AND PM.PrePOId=@PrePOId;

     SELECT PS.PrePOID ,PS.ItemId, PS.Qty, PS.Status, PS.DeliveryStatus,  I.PartNo , I.Description   FROM PrePOSub PS
	 inner join ItemMaster I on I.ItemId=PS.ItemId and I.IsActive=1 
	 WHERE PS.IsActive=1 AND PS.PrePOId=@PrePOId;
END
ELSE IF @Action='GetPrePODtls'
BEGIN
   
set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;
        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by          
							 case when @Sortcol=0 then A.prePoId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.InternalPONo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.InternalPONo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.PrePONo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.PrePONo	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.InternalPODate end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.InternalPODate end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.CustomerName	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.CustomerName end desc						    
                     ) as RowNum  
					 from (
								SELECT PM.PrePOId,PM.InternalPONo , PM.PrePONo, PM.InternalPODate,  C.CustomerName, 
								COUNT(*) over() as TotalCount 
								FROM PrePOMain PM
								inner join CustomerMaster C on C.CustomerId=PM.CustId and C.IsActive=1 
								WHERE PM.IsActive=1
						  )A where (@SearchString is null or A.InternalPONo like '%' +@SearchString+ '%' or
									A.PrePONo like '%' +@SearchString+ '%' or A.InternalPODate like '%' +@SearchString+ '%' or
									A.CustomerName like '%' + @SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetAllPrePODtls'
BEGIN
     SELECT PM.PrePOId, PM.InternalPONo, PM.PrePONo, PM.InternalPODate , PM.Status FROM PrePOMain PM
	 where PM.IsActive=1  ORDER BY PM.PrePOId DESC
END


COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[PrintSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PrintSP]
						 (
						 @Action VARCHAR(75)=null,
						 @PrePoId int=0,
						 @CustomerId int =0,
						 @GrnId INT =0,
						 @RouteEntryId INT =0,
						 @DCID INT =0,
						 @RMPOID INT =0,
						 @InvoiceId int =0,
						 @POId INT =0,
						 @supplierId INT =0,
						 @FromDate varchar(20)=null,
						 @ToDate varchar(20)=null,
						 @MaterialOutDCId int =0,
						 @InwardDcId int =0,
						 @VendorId int =0,
						 @DPRId INT =0,
						 @POType VARCHAR(20)=NULL,
						 @VendorPOId int =0,
						 @PurchaseReturnId INT =0
						 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='GetPrePOPrint'
BEGIN
     Select P.*,C.customername from PrePOMain P
	 inner join CustomerMaster C on C.customerId=P.CustId and C.IsActive=1
	 where P.isActive=1  and P.prePoId =@prePoId 

	 Select P.*,I.partNo,I.description,U.unitName,I.partNo+' ' + '-' +I.description as partNo_Desc
	 from PrePoSub P 
	 inner join itemMaster I on I.itemId=P.itemid and I.isActive=1
	 left join unitMaster U on U.unitId = I.UOMId and U.isActive =1
	 where P.isActive=1  and P.prePoId =@prePoId 
END
ELSE IF @Action='GetCompanyDtlsForPrint'
BEGIN
    select 'FullAddress'=(C.Address + ', ' +Ci.Name +' - ' +C.PinCode + ', ' + S.Name  +' - '+  Co.Name) ,
	C.Name,C.GSTIN,C.CINNo,C.PANNo,c.PhoneNo,C.BankAddress,C.AccountNo,C.IFSCCode,C.SWIFTCode,C.adCode,
	C.WebSite,C.Email
	from CompanyMaster C
	inner join CountryMaster Co on Co.ID=C.CountryId
	inner join StateMaster S on S.ID = C.StateId
	inner join CityMaster Ci on Ci.ID=C.CityId
	where IsActive ='1' order by CompanyMasterID desc
END
ELSE IF @Action='GetCustDtlsForPrint'
BEGIN
    Select C.B_DoorNo,C.B_StreetName,C.B_Block, Ci.Name as B_City,S.Name as B_State,Co.Name as B_Country from CustAddressDtls C
	inner join CountryMaster Co on Co.ID=C.B_Country
	inner join StateMaster S on S.ID = C.B_State
	inner join CityMaster Ci on Ci.ID=C.B_City
	where C.IsActive=1 and C.CustomerId=@CustomerId
END
ELSE IF @Action='GetGRNPrintDtls'
BEGIN
		SELECT  G.GRNNo,G.GRNDate,G.DCNo,G.DCDate,G.RefNo,G.RefDate,
		R.Description,GM.RMPONo,GM.Date as RMPODate,R.CodeNo as MaterialType,R.Dimension as Diameter,
		S.RecQty as Qty,U.UnitName, C.customername,
		A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' + isnull(A.B_streetName,'') + ' ' + isnull(Cd.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
		G.Remarks
		from GRNMain G
		inner join CustomerMaster C on G.supplierId = C.customerId  and C.isActive=1
		inner join grnSub S on G.grnId = S.grnId and S.IsActive=1 
		inner join RawMaterial R on S.rawMaterialId = R.rawMaterialId  AND R.isactive=1 
		left join CustAddressDtls A on G.supplierId = A.CustomerId and A.isactive=1
		left join CityMaster Cd on A.B_city = Cd.ID
		left join StateMaster Sm on A.B_state = Sm.ID
		inner join RMPOMain Gm on S.rmpoId = Gm.rmpoId and GM.IsActive=1 
		inner join RMPOSub  GMs on S.rmpoId = GMs.rmpoId and S.rawMaterialId = R.rawMaterialId  and GMs.isactive=1
		left join unitMaster U on Gms.unitId = U.unitId and u.isactive=1
		where G.isActive =1 and G.grnId =@GrnId 
END
ELSE IF @Action='GetRMStkPrintDtls'
BEGIN
         Select RW.RawMaterialId ,RM.CodeNo , RM.Description ,sum(cast(ISNULL(RW.QtyNos,'0.0') as decimal(18,2))) as AvlQtyNos,
		 sum(cast(isnull(RW.QtyKgs,'0.00') as decimal(18,3))) as AvlQty,U.UnitName
		from RMDimensionWiseStock RW
		inner join RawMaterial RM on RM.RawMaterialId=RW.RawMaterialId and RM.IsActive=1
		left join UnitMaster U on RM.UOMId=U.unitId and U.isactive=1
		where RW.IsActive=1 and RW.VendorId=0 and (cast(isnull(RW.QtyKgs,'0.00') as decimal(18,3)) >CAST('0' as decimal) or cast(isnull(RW.QtyNos,'0.00') as decimal(18,2)) >CAST('0' as decimal))
		group by RW.RawMaterialId, RM.CodeNo, RM.Description,U.UnitName
END
ELSE IF @Action='GetRMMidStkDtlsForPrint'
BEGIN
   Select R.Description,RM.Value1 + case when RM.Value2 is not null and RM.Value2<> '' then '*' +RM.Value2 else '' end +'*'+RM.Value3 as Value,
   O.OperationCode+'-'	+O.OperationName as OPCodeName,RM.Qty as BalQty from RMMidStock RM
   inner join RawMaterial R on R.RawMaterialId=RM.RawMaterialId and R.IsActive=1 
   inner join OperationMaster O on O.OperationId=RM.OperationId and O.IsActive=1 
   where RM.IsActive=1 
END
ELSE IF @Action='GetRouteCardPrintDtls'
BEGIN
		 Select  RC.POType,RC.RoutCardNo,RC.Date,R.Description as RawMaterialName,isnull(I.PartNo,JS.PartNo) as PartNo, ISNULL(I.Description,JS.ItemName) as ItemName,
		ISNULL(PM.PrePONo,JM.PONo) as PONo,ISNULL(PS.Qty,JS.Qty) as POQty,RC.ProcessQty,
		cast(RC.RouteEntryId as varchar) +'-'+ cast(RC.RoutLineNo as varchar) as 'barcode',U.UnitName
		 from RouteCardEntry RC
		left join RawMaterial R on RC.POType='CustomerPO' and R.RawMaterialId=RC.RawMaterialId and R.IsActive=1 
		left join PrePOMain PM on RC.POType='CustomerPO' and PM.PrePOId=RC.PrePOId and PM.IsActive=1
		left join JobOrderPOMain JM on RC.POType='JobOrderPO' and JM.JobOrderPOId=RC.PrePOId and JM.IsActive=1
		left join JobOrderPOSub JS on RC.POType='JobOrderPO' and  JS.JobOrderPOId=RC.PrePOId and JS.JobOrderPOSubId =RC.ItemId and JS.IsActive=1 
		left join PrePOSub PS on PS.PrePOId=RC.PrePOId and PS.ItemId=RC.ItemId and PS.IsActive=1 
		left join ItemMaster I on RC.POType='CustomerPO' and I.ItemId =RC.ItemId and I.IsActive=1 
		left join UnitMaster U on U.UnitId=case when RC.POType='CustomerPO' then I.UOMId else JS.UOMId end and U.IsActive=1 
		where RC.IsActive=1 and RC.RouteEntryId=@RouteEntryId
		order by RC.RoutLineNo asc
END
ELSE IF @Action='GetItemStkPrintDtls'
BEGIN
     select IT.ItemTypeName as ItemType, I.PartNo, I.Description, U.UnitName, S.Qty as Avlqty from ItemStock S
	inner join ItemMaster I on I.ItemId = S.ItemId and I.IsActive = 1
	inner join ItemTypeMaster IT on IT.ItemTypeId = I.ItemTypeId and IT.IsActive = 1
	inner join UnitMaster U on U.UnitId = I.UOMId and U.IsActive = 1
	WHERE S.IsActive=1 and cast(S.Qty as float)>0

END
ELSE IF @Action='GetStorePOGRNPrintDtls'
BEGIN
    select GM.GRNNo, GM.grnDate, GM.dcNo, GM.dcDate, GM.refNo, GM.refDate, GM.remarks, I.PartNo, I.Description, U.UnitName, PM.poNo, PM.Date as 'poDate',
	isnull(PM.RequiredByDate,'') as RequiredByDate, (cast(PS.GrnBalQty as decimal(18,3)) +cast(GS.RecQty as decimal(18,3))) as grnBalQty, GS.recQty,
	C.CustomerCode, C.CustomerName, C.PrintName, C.EmailId, C.MobileNo, C1.Name as city, CA.B_gstNo,
	CA.B_doorNo + ' ' + isnull(CA.B_block,'') +' ' + isnull(CA.B_streetName,'') + ' ' + isnull(C1.Name,'') + ' ' + ' '+ CA.B_pinCode as CustAddress
	from POGRNMain GM
	inner join POGRNSub GS on GS.GRNId = GM.GRNId and GS.IsActive = 1
	inner join ItemMaster I on I.ItemId = GS.ItemId and I.IsActive = 1
	inner join UnitMaster U on U.UnitId = I.UOMId and U.IsActive = 1
	inner join PurchaseOrderMain PM on  PM.poId = GS.poId and PM.isActive=1
	inner join PurchaseOrderSub PS on PS.poId = GS.poId and PS.itemId = GS.itemId and PS.isactive=1
	inner join CustomerMaster C On C.CustomerId = GM.SupplierId and C.isActive=1
	left join CustAddressDtls CA on CA.CustomerId = C.CustomerId and CA.IsActive = 1
	left join CityMaster C1 on C1.id = CA.B_City
	where GM.grnId = @grnId order by GM.grnId desc
END
ELSE IF @Action='GetVendorDCDtlsForPrint'
BEGIN
           Select DC.DCNo as MaterialOutDCNo,DC.DCDate,DC.NatureOfProcess,DC.AppxValue,
			isnull((SUM(cast(DS.Qty as float)) OVER (PARTITION BY DS.DCId)),0) AS TotalQty,
			DC.VehicleNo,C.CustomerCode, C.PrintName,C.EmailId as MailId,C.MobileNo,CA.B_GSTNo,
			CA.B_doorNo + ' ' + isnull(CA.B_block,'') +' ' +
			isnull(CA.B_streetName,'') + ' ' + isnull(SC.Name,'') + ' ' + ' '+CA.B_pinCode as CustAddress,
			CA.S_doorNo + ' ' + isnull(CA.S_block,'') +' ' +
			isnull(CA.S_streetName,'') + ' ' + isnull(BC.Name,'') + ' ' + ' '+CA.S_pinCode as ShippAddress,
			CA.S_gstNo as 'Shippgst',DC.Remarks,DC.DeliverySchedule,DC.DrawingEnclosed,DC.Types,
			O.OperationName as Process,DS.Qty,'Nos' as UnitName, 
			RM.CodeNo+'-' + RM.Description as RMDescription,
			RP.text1+'-'+RP.value1+','+RP.text2+'-'+RP.value2+','+RP.text3+'-'+RP.value3 as 'Dim',
			isnull(i.partNo,JS.PartNo)+'-'+  isnull(I.description,JS.itemName) +'_ Remarks:' + IsNull(DS.Remarks,'') as description
			 from DCEntryMain DC
			 inner join DCEntrySub DS on  DS.DCId=DC.DCId and DS.IsActive=1 
			 left join RMPlanning RP on RP.prePoId=DS.prePoId and DS.itemId=RP.itemId and RP.isActive='1'  and DC.poType='CustomerPO'
			 left join RawMaterial RM on DC.POType='CustomerPO' and  RM.rawMaterialId=DS.rawMaterialId and RM.isactive=1 
			 inner join OperationMaster O on O.OperationId =DS.operationId and o.isactive=1
			 left join ItemMaster I on DC.POType='CustomerPO' and I.ItemId=DS.ItemId and  I.IsActive=1 
			 left join JobOrderPOSub JS on DC.POType='JobOrderPO' and JS.JobOrderPOId=DS.PrePOId and  JS.JobOrderPOSubId=DS.ItemId and  JS.IsActive=1 
			 inner join CustomerMaster C on C.customerId = DC.SupplierId and C.IsActive=1 
			 left join CustAddressDtls CA on CA.customerId = DC.SupplierId and CA.IsActive=1
			 left join CityMaster SC on SC.id=CA.B_City 
			 left join CityMaster BC on BC.id=CA.S_City 
			 where DC.IsActive=1 and DC.DCID=@DCID
END
ELSE IF @Action='GetRMPOPrintDtls'
BEGIN
	   select IsNull(r.CuttingCharge,0) as 'CuttingCharge',
		IsNull(r.ServiceCharge,0) as 'ServiceCharge',
		IsNull(r.PackingCharge,0) as 'PackingCharge',r.*,
		isnull((SUM(cast(RS.NetRate as float) * CAST(RS.Qty as float))   OVER (PARTITION BY RS.RMPOId)),0) AS TaxableValue,
		c.customername,c.customerCode,a.B_doorNo,a.B_streetName,a.B_block,a.B_pinCode,a.B_gstNo,cm.Name,
		r.despatchthrough,c.EmailId As 'mailId',c.panNo,t.Terms as 'TermsName',p.paymentTerm,cm.Name as 'CityName',		
		A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' +
		isnull(A.B_streetName,'') + ' ' + isnull(Cm.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
		tm.taxName,c.mobileNo
		,F.freightName, Cd.empName as 'Preparedbyname',C.printName,	 r.specialInstruction as 'remarks',
		(select Case when Count(grnId)>0 then 'true' else 'false' end 
		from GRNMain where isActive=1 and  ','+RMPOIds+','  like '%,'+cast(R.rmpoId as varchar)+',%' ) as 'status'
		from RMPOMain r
		Inner JOIN RMPOSub RS ON RS.RMPOId  =r.RMPOId AND RS.IsActive=1
		inner join CustomerMaster c on c.customerId = r.supplierId and	c.isActive =1 
		left join CustAddressDtls a on a.CustomerId=c.customerId and a.isActive=1 
		left join CityMaster cm on cm.ID=a.B_city 
		left join Terms_ConditionMaster t on t.TermsId =r.termsId and t.IsActive =1
		left join PaymentTerms p on p.paymentId = r.PaymentTermsId and p.IsActive =1
		left join Taxmaster tm on tm.taxId =RS.TaxId and tm.IsActive =1 
		left join FreightMaster F on r.freightId = F.freightId and F.isactive=1
		left join employeeDetails Cd on r.preparedBy = Cd.empId and cd.isactive=1
		where c.CustomerType ='Supplier' and r.isActive =1  and r.rmpoId=@rmpoId 
		order by r.rmpoId desc

		select r.*,rm.description,rm.codeno, u.unitName,t.taxName,t.TaxValue,t.TaxType,
		rm.CodeNo+'-'+' '+rm.description  + '
		' + isnull(r.SpecificationRemarks,'') as type_desc,rp.specialInstruction as 'CityName' from RMPOSub r
		inner join RMPOMain rp on rp.rmpoId =r.rmpoId and rp.isActive='1'
		inner join RawMaterial rm on rm.rawMaterialId =r.rawMaterialId
		inner join unitMaster u on u.unitId =r.unitId
		left join taxMaster t on t.taxId=r.taxId and t.isActive=1
		where r.isActive ='1' and rm.isActive ='1' and u.isActive ='1' and r.rmpoId=@rmpoId ;

		 Select case when T.TaxType='GST' then 'CGST@'+cast(cast(T.TaxValue as float) /2  as varchar) else 'IGST@' + cast(T.TaxValue as varchar)   end  + ' %' as TaxName,
		case when T.TaxType='GST' then  cast((sum(cast(RS.TaxAmt as float))/2) as decimal(18,2)) else sum(cast(RS.TaxAmt as float)) end  as TaxAmt from RMPOSub RS
		 inner join TaxMaster T on T.TaxId=RS.TaxId and T.IsActive=1 
		 where RS.IsActive=1 and RS.RMPOID=@RMPOID 
		 group by RS.TaxId , T.TaxName,T.TaxType,T.TaxValue
		 union all 
		 Select 'SGST@'+cast(cast(T.TaxValue as float) /2  as varchar) as TaxName, cast((sum(cast(RS.TaxAmt as float))/2) as decimal(18,2)) as TaxAmt from RMPOSub RS
		 inner join TaxMaster T on T.TaxId=RS.TaxId and T.IsActive=1  and T.TaxType='GST'
		 where RS.IsActive=1 and RS.RMPOID=@RMPOID 
		 group by RS.TaxId , T.TaxName,T.TaxType,T.TaxValue 
END
ELSE IF @Action='GetGeneralTaxInvoice'
BEGIN
	   	select COALESCE(GM.Packing, 0) as Packing, IsNull(GM.CuttingCharge,0) as 'CuttingCharge', GM.CustomerId,
	IsNull(GM.ServiceCharge,0) as 'ServiceCharge', IsNull(GM.TransportCharge,0) as 'TransportCharge',
	C.printName, C.customerCode, C.CustomerName, T.TaxValue as value, T.taxName,
	CA.B_doorNo + ' ' + isnull(CA.B_block,'') +' ' +
	isnull(CA.B_streetName,'') + ' ' + isnull(C1.Name,'') + ' ' + ' '+ CA.B_pinCode as CustAddress,
	CA.S_doorNo + ' ' + isnull(CA.S_block,'') +' ' +
	isnull(CA.S_streetName,'') + ' ' + isnull(C2.Name,'') + ' ' + ' '+ CA.S_pinCode as CustAddressS, CA.S_gstNo, CA.B_gstNo,
	GM.AccountingYear,GM.InvoiceNo,GM.InvoiceDate,GM.TransportMode,GM.VehicleNo,GM.DateTimeOfSupply,GM.PlaceOfSuppply as PlaceOfSupply,
	GM.PONo,GM.PoDate,GM.DcNo,GM.DCDate,GM.POAmmendmentNo as POAmmendment,GM.POADate,GM.TotalAmt as Total,
	GM.FinalAmt as SubTotal,GM.ElectronicRefNo,GM.Remarks

	from GeneralInvoiceMain GM
	inner join CustomerMaster C On C.CustomerId = GM.CustomerId and C.isActive=1
	inner join TaxMaster T on T.taxId = GM.TaxId and T.isActive = 1
	left join CustAddressDtls CA on CA.CustomerId = C.CustomerId and CA.IsActive = 1
	left join CityMaster C1 on C1.id = CA.B_City
	left join CityMaster C2 on C2.id = CA.S_City
	where GM.IsActive = 1 and GM.InvoiceId = @InvoiceId order by GM.InvoiceId desc

	Select GS.* from GeneralInvoiceSub GS
	where GS.IsActive = 1 and GS.InvoiceId = @InvoiceId order by GS.InvoiceId asc
	select GM.InvoiceId, 'IGST@ '+ cast(cast((cast(T.TaxValue as decimal(18,2))) as decimal (18,2))as varchar)+' %' as 'TaxName',
	'TaxAmt' = cast((GM.TaxAmt) as decimal(18,2))
	from GeneralInvoiceMain GM
	inner join TaxMaster T on T.taxId = GM.TaxId and T.IsActive = 1
	where GM.IsActive = 1
	UNION ALL
	select GM.InvoiceId,'CGST@ '+ cast(cast((cast(T.TaxValue as decimal(18,2))/2) as decimal (18,2))as varchar)+' %' as 'TaxName',
	'TaxAmt' = cast((cast(GM.TaxAmt as decimal(18,2))/2) as decimal(18,2))
	from GeneralInvoiceMain GM
	inner join TaxMaster T on T.taxId = GM.TaxId and T.IsActive = 1
	where GM.IsActive = 1 and GM.InvoiceId = @InvoiceId and T.TaxName NOT like '%I%'
	UNION ALL
	select GM.InvoiceId,'SGST@ '+  cast(cast((cast(T.TaxValue as decimal(18,2))/2) as decimal (18,2))as varchar)+' %' as 'TaxName',
	'TaxAmt' = cast((cast(GM.TaxAmt as decimal(18,2))/2) as decimal(18,2))
	from GeneralInvoiceMain GM
	inner join TaxMaster T on T.taxId = GM.TaxId and T.IsActive = 1
	where T.isActive=1 and GM.IsActive = 1 and GM.InvoiceId = @InvoiceId and T.TaxName NOT like '%I%'
END
ELSE IF @Action='GetStorePOPrintDtls'
BEGIN
	   --POMain	 
			   select IsNull(NullIf(PM.OtherCharges,''),0) as 'OtherCharges',IsNull(NullIf(PM.CuttingCharge,''),0) as 'CuttingCharge',IsNull(NullIf(PM.ServiceCharge,''),0) as 'ServiceCharge',
			   IsNull(NullIf(PM.PackingCharge,''),0) as 'PackingCharge',PM.*,C.customername,
			   C.EmailId as 'mailId',C.printName,C.mobileNo,C.customerCode,
			   A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' +
				isnull(A.B_streetName,'') + ' ' + isnull(C1.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
				A.B_doorNo,A.B_block,
				A.B_streetName,C1.Name as city,A.B_pinCode, A.B_gstNo ,F.freightName,E.empName,
				P.paymentTerm,T.Terms as 'TermsName',TA.taxName,TA.TaxValue,TA.TaxType,
				(select top 1 grnId   from POGRNMain where isActive=1 and
				  ','+POIds+','  like '%,'+cast(PM.poId as varchar)+',%' ) as 'grnId',
				  isnull((SUM(cast(PS.NetRate as float) * CAST(PS.Qty as float))   OVER (PARTITION BY PS.POId)),0) AS TaxableValue
				from PurchaseOrderMain PM
				INNER JOIN PurchaseOrderSub PS ON PS.POId=PM.POId AND PS.IsActive=1
				inner join CustomerMaster C on C.customerId = PM.supplierId and C.isActive=1
				left join PaymentTerms P on P.paymentId= PM.PaymentTermsId and P.isActive=1
				left join Terms_ConditionMaster T on T.TermsId= PM.termsId and T.isActive=1
				left join employeeDetails E on E.empId= PM.preparedBy and E.isActive=1
				left join taxMaster TA on TA.taxId= PS.taxId and TA.isActive=1
				left join FreightMaster F on F.freightId= PM.freightId and F.isActive=1
				left join CustAddressDtls a on a.CustomerId=C.customerId and a.isActive ='1' 
				left join CityMaster C1 on C1.id=a.B_City
				where PM.isactive=1 and PM.poId=@poId order by PM.poId desc
	 -- PoSub
		select PS.*,PM.poNo,PM.date as poDate,PM.requiredBydate,I.partNo,i.description,i.UOMId as 'salesUnitId',U.unitName,
		t.taxName,t.TaxValue,t.TaxType  from PurchaseOrderSub PS 
		inner join itemMaster I on I.itemId = PS.itemId and I.isActive=1
		left join unitMaster U on U.unitId= I.UOMId and U.isactive=1
		left join taxMaster T on T.taxId=PS.taxId and T.isActive=1
		inner join PurchaseOrderMain PM on PS.poId=PM.poId and PM.isActive=1
		where PS.isactive=1 and PS.poId =@poId 

	 --po Tax
		Select case when T.TaxType='GST' then 'CGST@'+cast(cast(T.TaxValue as float) /2  as varchar) else 'IGST@' + cast(T.TaxValue as varchar)   end  + ' %' as TaxName,
			case when T.TaxType='GST' then  cast((sum(cast(RS.TaxAmt as float))/2) as decimal(18,2)) else sum(cast(RS.TaxAmt as float)) end  as TaxAmt from PurchaseOrderSub RS
			 inner join TaxMaster T on T.TaxId=RS.TaxId and T.IsActive=1 
			 where RS.IsActive=1 and RS.POId=@POId 
			 group by RS.TaxId , T.TaxName,T.TaxType,T.TaxValue
			 union all 
			 Select 'SGST@'+cast(cast(T.TaxValue as float) /2  as varchar) as TaxName, cast((sum(cast(RS.TaxAmt as float))/2) as decimal(18,2)) as TaxAmt from PurchaseOrderSub RS
			 inner join TaxMaster T on T.TaxId=RS.TaxId and T.IsActive=1  and T.TaxType='GST'
			 where RS.IsActive=1 and RS.POId=@POId 
			 group by RS.TaxId , T.TaxName,T.TaxType,T.TaxValue 
END
ELSE IF @Action='GetVendorDCOutSourcingPrintDtls'
BEGIN
             Select D.dcNo,D.dcDate,isnull(PM.PrePONo,JM.poNo) as PONo,isnull(I.partNo,JS.PartNo)as PartNo ,isnull(I.description,JS.itemName) as description,
			  O.OperationName,DS.Qty,unitName='NOS',C.printName from DCEntryMain D
			  INNER JOIN DCEntrySub DS ON DS.DCId=D.DCId AND DS.IsActive=1
			  left join PrePOMain PM on PM.prePoId=DS.prepoId and PM.isActive=1 and D.poType ='CustomerPO'
			  left join JobOrderPOMain JM on JM.jobOrderPoId=DS.prepoId and JM.isActive=1 and D.poType='JobOrderPO'
			  left join itemMaster I on I.itemId = DS.itemId and  I.isActive=1 and D.poType='CustomerPO'
			  left join JobOrderPOSub JS on JS.JobOrderPoId = DS.prepoId and JS.jobOrderPoSubId=DS.itemId and JS.isActive=1 and D.poType='JobOrderPO'
			  inner join OperationMaster O on O.OperationId = DS.operationId and O.IsActive=1
			  inner join CustomerMaster C on C.customerId = D.supplierId and C.isActive=1
			  where D.isActive=1 and D.supplierId=@supplierId and cast(D.dcDate as date ) between cast(@fromDate as date) and cast(@ToDate as date)
END
ELSE IF @Action='GetPendingDCPrintDtls'
BEGIN
                Select D.dcId, D.poType,D.dcNo,CONVERT(varchar,cast(d.DCDate as date),105) as dcDate,
				C.customername,ISNULL(I.description,JS.itemName) as ItemNAme,
				RM.description as RMName,DS.Qty,unitName='NOS' from DCEntryMain D
				INNER JOIN DCEntrySub DS ON DS.DCId =D.DCId AND DS.IsActive=1
				inner join CustomerMaster C on C.customerId=D.supplierId and C.isActive=1
				left join itemMaster I on I.itemId=DS.itemId and I.isActive=1 and D.poType='CustomerPO'
				left join RawMaterial RM on RM.rawMaterialId = dS.rawmaterialId and RM.isactive=1 and D.poType='CustomerPO'
				left join JobOrderPOSub JS on JS.JobOrderPoId=DS.prepoId and JS.jobOrderPoSubId = DS.itemId and JS.isactive=1 and D.poType='JobOrderPO'
				where D.isActive=1 and   CAST(isnull(DS.InwardBalQty,'0') as float) >0 AND @SupplierId in (0,D.SupplierId)
END
ELSE IF @Action='GetJobOrderInvoicePrintDtls'
BEGIN
		   Select I.InvoiceNo, I.invoiceDate, I.customerId, I.precarriageby, I.placeofreceipt, I.OriginCountry, I.destinationCountry,
		I.flightNo, I.portofLoading, I.portofdischarge, I.finaldestination, I.netAmt, I.freightAmt, I.grossAmt, C.customerName,
		C.TelephoneNo as telephone, C.ContactPerson, C.printName, CA.B_doorNo, CA.B_streetName, CA.B_pinCode, CA.B_Country as BCountry	,
		I.Terms_ConditionsDtls  
		from InvoiceMain I
		inner join CustomerMaster C on I.customerId = C.customerId and C.isactive = 1
		left join CustAddressDtls CA on CA.CustomerId = C.CustomerId and CA.IsActive = 1
		WHERE I.isactive=1 and I.InvoiceId = @InvoiceId;


		select S.POType, S.Qty, S.UnitWeight, cast(S.overallWeight as decimal(18,3)) as 'overallWeight', S.UnitPrice, S.TotalPrice,
		IsNull(I.partNo,js.partNo) as 'partNo', IsNull(I.description,js.itemName) as 'description', IsNull(PE.PONo,jm.PoNo) as poNo,
		IsNull(PE.Date, jm.Date) as poDate, I.HSNNumber as HSNNo, p.PrePONo, IsNull(p.internalPoDate,jm.Date) as 'internalPoDate',
		'SumQty' =(select Sum(cast(qty as int)) from InvoiceSub where isactive=1 and InvoiceId = @InvoiceId),
		'SumAmt' =(select Sum(cast(totalPrice as decimal)) from InvoiceSub where isactive=1 and InvoiceId = @InvoiceId)
		from InvoiceSub S
		left join itemMaster I on I.itemId = S.itemId and I.isactive = 1 and S.poType='CustomerPO'
		left join CustomerPO PE on PE.CustomerPOId = S.PrePOId and PE.isactive=1 and s.poType='CustomerPO'
		left join PrePOMain P on P.prePoId = S.prePoId and p.isActive='1' and S.poType='CustomerPO'
		left join JobOrderPOMain jm on jm.jobOrderPoId = S.PrePOId and jm.isActive='1' and S.poType='JobOrderPO'
		left join JobOrderPOSub js on js.JobOrderPoId = S.PrePOId and js.jobOrderPoSubId = S.itemId and js.IsActive='1'  and S.poType='JobOrderPO'
		where s.isactive=1 AND S.InvoiceId=@InvoiceId
END
ELSE IF @Action='GetMaterialOutDCPrintDtls'
BEGIN
    
		select MM.*,C.customername,C.EmailId as MailId,C.mobileNo,A.B_block,A.B_doorNo,C.printName
		,A.B_streetName,A.B_pinCode ,A.B_gstNo,C.customerCode,
		A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' +
		isnull(A.B_streetName,'') + ' ' + isnull(Cd.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
		A.S_doorNo + ' ' + isnull(A.S_block,'') +' ' +
		isnull(A.S_streetName,'') + ' ' + isnull(Cd.Name,'') + ' ' + ' '+A.S_pinCode as ShippAddress,A.S_gstNo as 'Shippgst',
		Cd.Name as 'Cityname',Sm.Name as 'Statename' from MaterialOutDCMain MM
		inner join CustomerMaster C on MM.CustomerId=C.customerId and C.isActive=1
		left join CustAddressDtls A on C.customerId = A.CustomerId and A.isactive=1
		left join CityMaster Cd on A.B_city = Cd.ID 
		left join StateMaster Sm on A.B_state = Sm.ID 
		where MM.isActive=1  and MM.materialOutDCId =@MaterialOutDCId
		order by MM.materialOutDCId desc

   select B.*,'RemainingQty' =  (B.totalQty - coalesce(b.recQty,0)) from(
	Select MS.*,MS.itemDescription+'
	'+isnull(MS.remarks,'') as desc_Remarks,U.unitName,
	isnull((SUM(cast(MS.Qty as float)) OVER (PARTITION BY MS.MaterialOutDCId)),0) AS TotalQty,
	isnull((SUM(cast(MS.Qty as float) - cast(isnull(MS.InwardBalQty,'0') as float)) OVER (PARTITION BY MS.MaterialOutDCId)),0) AS RecQty
	 from MaterialOutDCSub MS
	inner join unitMaster U on U.unitId=MS.uom and U.isActive=1
	where MS.isActive=1 and materialOutDCId=@MaterialOutDCId )B order by B.materialOutDCId asc
END
ELSE IF @Action='GetDCInwardPrintDtls'
BEGIN
      Select IsNull(NullIf(IDS.InwardDcQty,''),0) as 'inwarddcQty',ID.*, 
	             '0' as 'jwNo', IsNull(NullIf(IDS.InwardDcQty,''),0) as 'okqty','0' as rejQty,
				  C.customername as vendorName,O.OperationName,DC.dcNo ,DC.dcDate,cuttingNos='',
				 isnull(I.description,JS.itemName) as description,ISNULL(PM.PrePONo,JM.poNo) as poNo,
				 isnull(I.description,JS.itemName)  as RMDescription,I.partno as 'RMCodeno',
				 I.partNo+' ' + '-' +I.description  as partNo_Desc,I.partno,
				A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' +
			    isnull(A.B_streetName,'') + ' ' + isnull(C1.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
				DS.Qty as DCQty,
		     	cast(IsNull(NullIf(RP.weight,''),0) as decimal(18,3)) * cast(IsNull(NullIf(IDS.InwardDcQty,''),0) as int) as usedRminKgs,
				R.text1,R.text2,R.text3,unitName='NOS',RP.value1,RP.value2,RP.value3,
				'PendingQty' = case when (IsNull(cast(IDS.InwardDCQty as int),0)- IsNull((select SUM(cast(IsNull(NullIf(InwardDcQty,''),0) as Int))
				 from InwardDCSub where dcId=ID.dcId and IsActive='1'),0)) < 0
				 then '0'  else (IsNull(cast(IDS.InwardDCQty as int),0)- IsNull((select SUM(cast(IsNull(NullIf(InwardDcQty,''),0) as Int))
				 from InwardDCSub where dcId=ID.dcId and IsActive='1'),0)) end 
				 from InwardDCMain ID 
				INNER JOIN InwardDCSub IDS ON IDs.InwardId=Id.InwardDCId AND IDS.IsActive=1
				inner join CustomerMaster C on C.customerId = ID.vendorId and C.isactive=1 
				inner join OperationMaster O on O.OperationId=IDS.OperationId and O.isactive=1
				inner join DCEntryMain DC on DC.dcId = ID.dcId and DC.isactive=1 and DC.poType=ID.poType
				inner join DCEntrySub DS on DS.DCId=IDS.DCId and DS.RouteEntryId=IDS.RouteEntryId and DS.RoutLineNo=IDS.RoutLineNo and DS.IsActive=1 
				left join itemMaster I on I.itemId = IDS.ItemId and I.isactive=1 and ID.poType='CustomerPO'
				left join PrePOMain PM on PM.prepoId = IDS.PrePOId and PM.isactive=1 and ID.poType='CustomerPO'
			 -- left join RouteCardEntry rc on rc.itemId = ID.itemId and rc.prepoId=ID.prepoId and rc.routLineNo=ID.routLineNo and rc.isactive=1 and rc.poType='CustomerPO'
			    left join RawMaterial R on R.rawMaterialId = IDS.RawMaterialId and R.isactive=1 and ID.poType='CustomerPO'				
				left join RmPlanning RP on RP.prepoId = IDS.prepoId and IDS.itemId = RP.itemId and RP.isactive=1 and ID.poType='CustomerPO'
				left join CustAddressDtls a on a.CustomerId=C.customerId and a.isActive ='1'
				left join CityMaster C1 on C1.id=a.B_City
				left join JobOrderPOMain JM on JM.jobOrderPoId=IDS.prepoId and JM.isActive=1 and ID.poType='JobOrderPO'
			    left join JobOrderPOSub JS on JS.JobOrderPoId = IDS.prepoId and JS.jobOrderPoSubId=IDS.itemId and JS.isActive=1 
			    and ID.poType='JobOrderPO'
				WHERE ID.isactive=1 and  IsNull(IDS.inwarddcQty,0) <>'0' 
				and (@InwardDcId=0 or ID.InwardDcId=@InwardDcId) order by ID.InwardDCNo asc
END
ELSE IF @Action='GetSalesInvoicePrintDtls'
BEGIN
			 Select I.InvoiceNo, I.invoiceDate, I.customerId, I.precarriageby, I.placeofreceipt, I.OriginCountry, I.destinationCountry,
		I.flightNo, I.portofLoading, I.portofdischarge, I.finaldestination, I.netAmt, I.freightAmt, I.grossAmt, C.customerName,
		C.TelephoneNo as telephone, C.ContactPerson, C.printName, CA.B_doorNo, CA.B_streetName, CA.B_pinCode, CA.B_Country as BCountry	,
		I.Terms_ConditionsDtls  			  
		from InvoiceMain I
		inner join CustomerMaster C on I.customerId = C.customerId and C.isactive = 1
		left join CustAddressDtls CA on CA.CustomerId = C.CustomerId and CA.IsActive = 1
		WHERE I.isactive=1 and I.InvoiceId = @InvoiceId;


		select S.POType, S.Qty, S.UnitWeight, cast(S.overallWeight as decimal(18,3)) as 'overallWeight', S.UnitPrice, S.TotalPrice,
		IsNull(I.partNo,js.partNo) as 'partNo', IsNull(I.description,js.itemName) as 'description', IsNull(PE.PONo,jm.PoNo) as poNo,
		IsNull(PE.Date, jm.Date) as poDate, I.HSNNumber as HSNNo, p.PrePONo, IsNull(p.internalPoDate,jm.Date) as 'internalPoDate',
		'SumQty' =(select Sum(cast(qty as int)) from InvoiceSub where isactive=1 and InvoiceId = @InvoiceId),
		'SumAmt' =(select Sum(cast(totalPrice as decimal)) from InvoiceSub where isactive=1 and InvoiceId = @InvoiceId)
		from InvoiceSub S
		left join itemMaster I on I.itemId = S.itemId and I.isactive = 1 and S.poType='CustomerPO'
		left join CustomerPO PE on PE.CustomerPOId = S.PrePOId and PE.isactive=1 and s.poType='CustomerPO'
		left join PrePOMain P on P.prePoId = S.prePoId and p.isActive='1' and S.poType='CustomerPO'
		left join JobOrderPOMain jm on jm.jobOrderPoId = S.PrePOId and jm.isActive='1' and S.poType='JobOrderPO'
		left join JobOrderPOSub js on js.JobOrderPoId = S.PrePOId and js.jobOrderPoSubId = S.itemId and js.IsActive='1'  and S.poType='JobOrderPO'
		where s.isactive=1 AND S.InvoiceId=@InvoiceId;

END
ELSE IF @Action='GetMachineOutDCPrintDtls'
BEGIN
     	select MM.*,C.customername,C.EmailId AS MailId,C.mobileNo,A.B_block,A.B_doorNo,C.printName
		,A.B_streetName,A.B_pinCode ,A.B_gstNo,C.customerCode,
		A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' +
		isnull(A.B_streetName,'') + ' ' + isnull(Cd.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
		A.S_doorNo + ' ' + isnull(A.S_block,'') +' ' +
		isnull(A.S_streetName,'') + ' ' + isnull(Cd.Name,'') + ' ' + ' '+A.S_pinCode as ShippAddress,A.S_gstNo as 'Shippgst',
		Cd.Name as 'Cityname',Sm.Name as 'Statename' from MachineWiseDcMain MM
		inner join CustomerMaster C on MM.SupplierId=C.customerId and C.isActive=1
		left join CustAddressDtls A on C.customerId = A.CustomerId and A.isactive=1
		left join CityMaster Cd on A.B_city = Cd.ID 
		left join StateMaster Sm on A.B_state = Sm.ID 
		where MM.isActive=1 and MM.DcId =@DcId
		order by MM.DcId desc

		select B.*,'RemainingQty' =  (B.totalQty - coalesce(b.recQty,0)) from(
		Select MS.*,(MD.MachineCode+'-'+MD.MachineName)+'
		'+isnull(MS.remarks,'') as desc_Remarks,U.unitName,
		(select SUM(cast(qty as decimal(18,3))) from MachineWiseDcSub where isActive='1'and dcid =@DcId) as totalQty,
		(select sum(cast(coalesce(qty,0) as decimal(18,3))) from MachineWiseDcSub where  IsActive='1' and dcid=@DcId group by dcid) as recQty
		from MachineWiseDcSub MS
		inner join unitMaster U on U.unitId=MS.UnitId and U.isActive=1
		inner join MachineDetails MD On MD.MachineId=MS.MachineId
		where MS.isActive=1 AND MD.IsActive=1 and DcId=@DcId )B order by B.DcId asc
END
ELSE IF @Action='GetVendorRMStkPrintDtls'
BEGIN
       Select RW.RawMaterialId ,RM.CodeNo , RM.Description ,
		 sum(cast(isnull(RW.QtyKgs,'0.00') as decimal(18,3))) as Qty,U.UnitName,
		 C.CustomerName
		from RMDimensionWiseStock RW
		inner join RawMaterial RM on RM.RawMaterialId=RW.RawMaterialId and RM.IsActive=1
		inner join CustomerMaster C on C.CustomerId=RW.VendorId and C.IsActive=1 
		left join UnitMaster U on RM.UOMId=U.unitId and U.isactive=1
		where RW.IsActive=1 and RW.VendorId=@VendorId and (cast(isnull(RW.QtyKgs,'0.00') as decimal(18,3)) >CAST('0' as decimal) or cast(isnull(RW.QtyNos,'0.00') as decimal(18,2)) >CAST('0' as decimal))
		group by RW.RawMaterialId, RM.CodeNo, RM.Description,U.UnitName,C.CustomerName
END
ELSE IF @Action='GetMachineOutInward_PrintDtls'
BEGIN
	  Select m.*,c.customername as 'VendorName',A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' +
	isnull(A.B_streetName,'') + ' ' + isnull(C1.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
	mm.DCNo,mm.date as 'MaterialOutDate',(MD.MachineCode+'-'+MD.MachineName) as itemDescription,process,ms.qty,mi.RecQty as 'ReceivedQty'
    from MachineOutInwardMain m
	inner join MachineWiseDCMain mm on mm.DcId =m.dcid and mm.isActive='1'
	inner join MachineOutInwardSub mi on mi.dcId =m.dcid  and mi.isActive='1' and MI.InwardId=@InwardDcId
	inner join MachineWiseDcSub ms on  ms.DcId =m.dcid and ms.MachineId=mi.MachineId and ms.isActive='1'  
	inner join MachineDetails MD ON MD.MachineId = mi.MachineId and MD.IsActive=1
	inner join CustomerMaster c on c.customerId =mm.SupplierId
	left join CustAddressDtls a on a.customerId=C.customerId and a.isActive ='1'
	left join CityMaster C1 on C1.id=a.B_City
	where m.isactive='1' and m.InwardId=@InwardDcId  
END
ELSE IF @Action='GetMaterialOutInwardPrintDtls'
BEGIN
    Select  m.*,c.customername as 'VendorName',A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' +
	isnull(A.B_streetName,'') + ' ' + isnull(C1.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
	mm.materialOutDCNo,mm.date as 'MaterialOutDate',itemDescription,process,ms.qty,mi.qty as 'ReceivedQty'  from MaterialoutinwardMain m
	inner join CustomerMaster c on c.customerId =m.CustomerId  and c.IsActive='1'
	left join CustAddressDtls a on a.customerId=C.customerId and a.isActive ='1'
	left join CityMaster C1 on C1.id=a.B_City
	inner join MaterialOutDCMain mm on mm.materialOutDCId =m.dcid and mm.isActive='1'
	inner join MaterialOutDCSub ms on ms.materialOutDCId =m.dcid and ms.isActive='1'
	inner join MaterialoutinwardSub mi on mi.dcId =m.dcid and mi.materialoutdcsubid =ms.materialOutDCSubId and mi.isActive='1' and MI.InwardId=@InwardDcId
	where m.isactive='1'  and m.inwardid=@InwardDcId
END
ELSE IF @Action='GetProdPrintDtls'
BEGIN
			   Select D.DPRDate as EntryDate,M.MachineCode,M.MachineName , 
			case when D.DPRKey='Setting' then D.StartTime +' To ' + D.EndTime else F.SetupFrom +' To ' + F.SetupTo end  as SettingTime,
			S.ShiftName, E.EmpName,S.FromTime +' To ' + S.ToTime as ShiftTime,
			isnull(I.PartNo,JS.PartNo) as PartNo,ISNULL(I.Description, JS.ItemName) as Description,
			case when D.DPRKey='Setting' then '' else D.StartTime end as StartTime, 
			case when D.DPRKey='Setting' then '' else D.EndTime end as EndTime,
			F.QCFRom,F.QCTo,O.OperationName,
			 'QcTotal' =DATEDIFF(minute, cast(F.QcFrom as time), cast(F.QcTo as time)),
case when D.DPRKey='Production' then   DATEDIFF(minute, cast(D.startTime as time), cast(D.endTime as time)) else '' end as 'ProdTotal'
			from DPREntry D
			left join FirstPieceInspectionMain F on F.DPRId=D.DPRId and F.IsActive=1 
			left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
			left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
			left join MachineDetails M on M.MachineId = D.machineId and M.IsActive=1
			inner join ShiftMaster S on S.ShiftId=D.ShiftId and S.IsActive=1 
			inner join EmployeeDetails E on E.EmpId=D.ProdEmpId and E.IsActive =1 
			inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
			where D.IsActive=1 and D.DPRId=@DPRId;
END
ELSE IF @Action='GetVendorPOPrintDtls'
BEGIN
    Select V.VendorPONo,V.VendorPODate,C.CustomerCode,C.PrintName,
	CA.B_doorNo + ' ' + isnull(CA.B_block,'') +' ' +isnull(CA.B_streetName,'') + ' ' + isnull(Ci.Name,'') + ' ' + ' '+CA.B_pinCode as CustAddress,
	CA.B_GSTNo,isnull(I.PartNo,JS.PartNo) +' - ' + isnull(I.Description,JS.ItemName) as PartNo_Desc,
	O.OperationName,  VS.qty,'Nos' as UnitName,VS.Rate,VS.Amount,
	cast(case when VS.TaxAmt is null or VS.TaxAmt ='' then '0' else VS.TaxAmt end as decimal(18,2)) as TaxAmt
	from VendorPOMain V
	inner join VendorPOSub VS on VS.VendorPOId=V.VendorPOID and VS.IsActive=1 
	left join ItemMaster I on @POType='CustomerPO' and VS.ItemId=I.ItemId and I.IsActive=1
	left join JobOrderPOSub JS on @POType='JobOrderPO' and  JS.JobOrderPOId=VS.PrePOId and JS.JobOrderPOSubId=VS.ItemId  and JS.IsActive=1 
	inner join OperationMaster O On O.OperationId=VS.OperationId and O.IsActive=1 
	INNER JOIN CustomerMaster C ON C.CustomerId=V.VendorId AND C.IsActive=1 
	left join CustAddressDtls CA on CA.CustomerId=C.CustomerId and CA.IsActive=1 
	left join CityMaster Ci on Ci.id=CA.B_City
	where V.IsActive=1 and V.VendorPOId=@VendorPOId ;



		Select case when T.TaxType='GST' then 'CGST@'+cast(cast(T.TaxValue as float) /2  as varchar) else 'IGST@' + cast(T.TaxValue as varchar)   end  + ' %' as TaxName,
		case when T.TaxType='GST' then  cast((sum(cast(RS.TaxAmt as float))/2) as decimal(18,2)) else sum(cast(RS.TaxAmt as float)) end  as TaxAmt 
		from VendorPOSub RS
		inner join TaxMaster T on T.TaxId=RS.TaxId and T.IsActive=1 
		where RS.IsActive=1 and RS.VendorPOId=@VendorPOId 
		group by RS.TaxId , T.TaxName,T.TaxType,T.TaxValue
		union all 
		Select 'SGST@'+cast(cast(T.TaxValue as float) /2  as varchar) as TaxName, cast((sum(cast(RS.TaxAmt as float))/2) as decimal(18,2)) as TaxAmt 
		from VendorPOSub RS
		inner join TaxMaster T on T.TaxId=RS.TaxId and T.IsActive=1  and T.TaxType='GST'
		where RS.IsActive=1 and RS.VendorPOId=@VendorPOId 
		group by RS.TaxId , T.TaxName,T.TaxType,T.TaxValue 
END
ELSE IF @Action='GetPurchaseReturnPrintDtls'
BEGIN
		Select COALESCE(g.Packing_Forwarding,0) as 'Packing', g.*,C.printName,C.customerCode,t.TaxValue,t.taxName,c.customername,
		 A.B_doorNo + ' ' + isnull(A.B_block,'') +' ' +
				isnull(A.B_streetName,'') + ' ' + isnull(C1.Name,'') + ' ' + ' '+A.B_pinCode as CustAddress,
		A.S_doorNo + ' ' + isnull(A.S_block,'') +' ' +
				isnull(A.S_streetName,'') + ' ' + isnull(C2.Name,'') + ' ' + ' '+A.S_pinCode as CustAddressS      
		from PurchaseReturnMain g
		inner join GRNMain m on m.grnId =g.grnId 
		inner join CustomerMaster C on c.customerId = m.supplierId
		inner join taxMaster t on t.taxId =g.TaxId  and t.isActive='1'
		left join CustAddressDtls a on a.customerId=C.customerId and a.isActive ='1' 
		left join CityMaster C1 on C1.id=a.B_City
		left join CityMaster C2 on C2.id=a.S_City
		where g.IsActive='1' and C.isActive='1' and g.PurchaseReturnId =@PurchaseReturnId


		Select r.description,g.Specification as 'HSNCode',g.*,u.unitName from PurchaseReturnSub g	
		inner join RawMaterial r on r.rawMaterialId =g.RawMaterialId and r.isActive ='1'
		inner join unitMaster u on u.unitId =r.uomId and u.isActive ='1'
		where g.IsActive ='1' and g.PurchaseReturnId =@PurchaseReturnId 

	
			Select case when T.TaxType='GST' then 'CGST@'+cast(cast(T.TaxValue as float) /2  as varchar) else 'IGST@' + cast(T.TaxValue as varchar)   end  + ' %' as TaxName,
			case when T.TaxType='GST' then  cast((sum(cast(RS.TaxAmt as float))/2) as decimal(18,2)) else sum(cast(RS.TaxAmt as float)) end  as TaxAmt 
			from PurchaseReturnMain RS
			inner join TaxMaster T on T.TaxId=RS.TaxId and T.IsActive=1 
			where RS.IsActive=1 and RS.PurchaseReturnId=@PurchaseReturnId 
			group by RS.TaxId , T.TaxName,T.TaxType,T.TaxValue
			union all 
			Select 'SGST@'+cast(cast(T.TaxValue as float) /2  as varchar) as TaxName, cast((sum(cast(RS.TaxAmt as float))/2) as decimal(18,2)) as TaxAmt 
			from PurchaseReturnMain RS
			inner join TaxMaster T on T.TaxId=RS.TaxId and T.IsActive=1  and T.TaxType='GST'
			where RS.IsActive=1 and RS.PurchaseReturnId=@PurchaseReturnId 
			group by RS.TaxId , T.TaxName,T.TaxType,T.TaxValue 
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[PurchaseIndentEntrySP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PurchaseIndentEntrySP]
									 (
									 @Action varchar(75)=null,
									 @PurIndentId int =0,
									 @PurchaseIndentEntryId int =0,
									 @PurchaseEntryNo varchar(20)=null,
									 @Date varchar(20)=null,
									 @VendorName varchar(75)=null,
									 @PurchaseIndentId int =0,
									 @TotalAmt varchar(20)=null,
									 @TaxAmt varchar(20)=null,
									 @NetAmt varchar(20)=null,
									 @Remarks varchar(max)=null,
									 @ApprovedStatus varchar(20)=null,
									 @CreatedBy int=0,
									 @PurchaseIndentEntrySub PurchaseIndentEntrySub readonly
									 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertPurchaseIndentEntry'
BEGIN
    SET @PurchaseIndentEntryId =ISNULL((SELECT TOP 1 PurchaseIndentEntryId+1 FROM PurchaseIndentEntryMain ORDER BY PurchaseIndentEntryId DESC),1)
	set @PurchaseEntryNo =@PurchaseIndentEntryId
 INSERT INTO PurchaseIndentEntryMain
									  (
									  PurchaseIndentEntryId,
									  PurchaseEntryNo,
									  Date,
									  VendorName,
									  PurchaseIndentId,
									  TotalAmt,
									  TaxAmt,
									  NetAmt,
									  Remarks,
									  CreatedBy
									  )
							VALUES
									(
									@PurchaseIndentEntryId,
									@PurchaseEntryNo,
									@Date,
									@VendorName,
									@PurchaseIndentId,
									@TotalAmt,
									@TaxAmt,
									@NetAmt,
									@Remarks,
									@CreatedBy
									)
			INSERT INTO PurchaseIndentEntrySub
											(
											PurchaseIndentEntryId,
											Type,
											ItemId,
											ReceivedQty,
											Rate,
											DiscPer,
											DiscAmt,
											NetRate,
											TaxId,
											TaxAmt,
											Amount,
											CreatedBy
											)
								Select  @PurchaseIndentEntryId,
										Type,
										ItemId,
										ReceivedQty,
										Rate,
										DiscPer,
										DiscAmt,
										NetRate,
										TaxId,
										TaxAmt,
										Amount,
										@CreatedBy from @PurchaseIndentEntrySub;

UPDATE PS SET PS.ReceivdQty=CAST(ISNULL(PS.ReceivdQty,'0') AS float) +  CAST(ISNULL(T.ReceivedQty,'0') as float)
FROM PurchaseIndentSub PS
INNER JOIN @PurchaseIndentEntrySub T ON  T.ItemId=PS.ItemId AND T.Type=PS.Type 
WHERE PS.IsActive=1 and PS.PurIndentId=@PurchaseIndentId ;

				SELECT '1'


END
ELSE IF @Action='GetPurchaseIndentEntryDtls'
BEGIN
     SELECT PM.PurchaseIndentEntryId, PM.PurchaseEntryNo,PM.Date,PM.VendorName,PM.NetAmt, ApprovedStatus FROM PurchaseIndentEntryMain PM
	 WHERE PM.IsActive=1 ORDER BY PM.PurchaseIndentEntryId DESC	 

END
ELSE IF @Action='GetPurchaseIndentEntryDtlsById'
BEGIN
    SELECT PM.PurchaseEntryNo,PM.Date as 'PurchaseEntryDate',PM.VendorName,PM.PurchaseIndentId,PM.TotalAmt,PM.TaxAmt,PM.NetAmt,
	PM.Remarks, IM.Date,E.EmpName as IndentersName
	 FROM PurchaseIndentEntryMain PM
	left JOIN PurchaseIndentMain IM ON IM.PurIndentId=PM.PurchaseIndentId AND IM.IsActive=1 
	left JOIN EmployeeDetails E on E.EmpId=IM.IndentersId and E.IsActive=1 
	WHERE PM.IsActive=1 AND PurchaseIndentEntryId=@PurchaseIndentEntryId;

	SELECT I.Description,PS.ReceivedQty,PS.Rate,Ps.DiscPer,Ps.DiscAmt,
	PS.NetRate,Ps.TaxId,PS.TaxAmt,PS.Amount FROM PurchaseIndentEntrySub PS
	left JOIN ItemMaster I ON PS.Type='Item' and  I.ItemId=PS.ItemId AND I.IsActive=1 
	WHERE PS.IsActive=1 AND PS.PurchaseIndentEntryId=@PurchaseIndentEntryId;
END
ELSE IF @Action='GetPurIndentMainDtlsForIndentEntry'
BEGIN    
    SET @PurchaseIndentId =(SELECT TOP 1 PurchaseIndentId FROM PurchaseIndentEntryMain PM WHERE PM.IsActive=1 and  PurchaseIndentEntryId=@PurchaseIndentEntryId)

    SELECT PM.PurIndentId,PM.PurIndentNo,PM.Date,E.EmpName as IndentersName FROM PurchaseIndentSub PS
	INNER JOIN PurchaseIndentMain PM ON PM.PurIndentId=PS.PurIndentId AND PM.IsActive=1 
	INNER JOIN EmployeeDetails E on E.EmpId=PM.IndentersId and E.IsActive=1 
	WHERE PS.IsActive=1 and  
	(PS.PurIndentId =@PurchaseIndentId or 
	CAST(ISNULL(PS.Qty,'0') as float) - CAST(ISNULL(PS.ReceivdQty,'0') AS float) > 0)
	GROUP BY PM.PurIndentId,PM.PurIndentNo,PM.Date,E.EmpName
END
ELSE IF @Action='GetIndentSubDtlsForIndentEntry'
BEGIN
	Select PS.Type, PS.ItemId,I.PartNo +'-'+I.Description as Item ,  PS.Qty as IndentQty,PS.Rate,PS.Amount from PurchaseIndentSub PS
	left join ItemMaster I on PS.Type='Item' and I.ItemId=PS.ItemId and I.IsActive=1 
	where PS.IsActive=1 and (PS.PurIndentId=@PurchaseIndentId or CAST(ISNULL(PS.Qty,'0') as float) - CAST(ISNULL(PS.ReceivdQty,'0') AS float) > 0)
END
ELSE IF @Action='ApprovePurIndentEntry'
BEGIN 
    Update PurchaseIndentEntryMain Set ApprovedStatus='Yes' , ApprovedOn=getDate() where PurchaseIndentEntryId=@PurchaseIndentEntryId;
     UPDATE SI SET SI.QTY= CAST(ISNULL(SI.QTY,'0') AS decimal(18,2)) + cast(isnull(PS.ReceivedQty  ,'0') as float)
	 FROM ItemStock SI
	 INNER JOIN PurchaseIndentEntrySub PS  ON PS.Type='Item' and PS.ItemId=SI.ItemId and  PS.IsaCTIVE=1 AND PS.PurchaseIndentEntryId=@PurchaseIndentEntryId
	 WHERE SI.IsActive=1 

	 INSERT INTO ItemStock
						   ( 
						   I.ItemId,
						   Qty,
						   CreatedBy
						   )
				SELECT   PS.ItemId,
				         PS.ReceivedQty,
						 @CreatedBy			
					FROM PurchaseIndentEntrySub PS
					where PS.IsaCTIVE=1 AND PS.PurchaseIndentEntryId=@PurchaseIndentEntryId 
					and PS.ItemId not in (Select distinct ItemId from ItemStock where IsActive=1 )
      SELECT '1';
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[PurchaseIndentSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PurchaseIndentSP]
								  (
								  @Action varchar(75)=null,
								  @PurIndentId int =0,
								  @PurIndentNo varchar(20)=null,
								  @Date varchar(20)=null,
								  @IndentersId int=0,
								  @Remarks varchar(max)=null,
								  @AmtGiven varchar(20)=null,
								  @CreatedBy int =0,
								  @PurchaseIndentSub PurchaseIndentSub READONLY,
								  @FromDate varchar(20)=null,
								  @ToDate varchar(20)=null
								  )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertPurchaseIndent'
BEGIN
   IF @PurIndentId=0
   BEGIN
      SET @PurIndentId=ISNULL((Select TOP 1 PurIndentId+1 FROM PurchaseIndentMain ORDER BY PurIndentId DESC ),1);
	  SET @PurIndentNo=@PurIndentId;
   END
   ELSE
   BEGIN
       UPDATE PurchaseIndentMain SET IsActive=0 where PurIndentId=@PurIndentId;
       UPDATE PurchaseIndentSub SET IsActive=0 where PurIndentId=@PurIndentId;
   END
       INSERT INTO [dbo].[PurchaseIndentMain]
								   (
								    [PurIndentId]
								   ,[PurIndentNo]
								   ,[Date]
								   ,[IndentersId]
								   ,[Remarks]
								   ,[AmtGiven]
								   ,[CreatedBy]
								   )
						VALUES
									(
									@PurIndentId
								   ,@PurIndentNo
								   ,@Date
								   ,@IndentersId
								   ,@Remarks
								   ,@AmtGiven
								   ,@CreatedBy
								   )
     
		INSERT INTO [dbo].[PurchaseIndentSub]
				                 (
								    [PurIndentId]
								   ,[Type]
								   ,[ItemId]
								   ,[Qty]
								   ,[ReceivdQty]
								   ,[UnitId]
								   ,[Purpose]
								   ,[Rate]
								   ,[Amount]
								   ,[CreatedBy]
								   )
						SELECT     @PurIndentId
						           ,[Type]
								   ,[ItemId]
								   ,[Qty]
								   ,'0.00'
								   ,[UnitId]
								   ,[Purpose]
								   ,[Rate]
								   ,[Amount]
								   ,@CreatedBy from @PurchaseIndentSub
									
   Select '1'

END
ELSE IF @Action='GetPurchaseIndentDtls'
BEGIN
   SELECT PM.PurIndentId, PM.PurIndentNo, PM.Date,E.EmpName as IndentersName, PM.AmtGiven FROM PurchaseIndentMain PM
	inner join EmployeeDetails E on E.EmpId=PM.IndentersId and E.IsActive= 1
	where PM.IsActive=1  and @IndentersId in (0,PM.IndentersId) and cast(PM.Date as date) between cast(@FromDate as date) and cast(@ToDate as date)
END
ELSE IF @Action='GetPurchaseIndentDtlsById'
BEGIN
     SELECT PM.PurIndentNo, PM.Date, PM.IndentersId, PM.Remarks, PM.AmtGiven FROM PurchaseIndentMain PM
	 WHERE PM.IsActive=1 AND PM.PurIndentId=@PurIndentId;

	 
     SELECT PS.Type, ISNULL(I.ItemTypeId,1) as TypeId, PS.ItemId, PS.Qty, PS.UnitId, PS.Purpose, PS.Rate, PS.Amount FROM PurchaseIndentSub PS
	 left join ItemMaster I on PS.Type='Item' and  I.ItemId=PS.ItemId and I.Isactive=1
	 WHERE PS.IsActive=1 AND PS.PurIndentId=@PurIndentId;



END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[PurchaseOrderSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PurchaseOrderSP]
								(
								@Action varchar(75)=null,
								@POId int =0,
								@PONo varchar(20)=null,
								@Date varchar(20)=null,
								@ValidDate varchar(20)=null,
								@SupplierId int=0,
								@TermsId int=0,
								@PaymentTermsId int =0,
								@DespatchThrough varchar(50)=null,
								@RequiredByDate varchar(20)=null,
								@PreparedBy int=0,
								@TotalAmt varchar(20)=null,
								@TaxAmt varchar(20)=null,
								@FreightId int =0,
								@FreightAmt varchar(20)=null,
								@ServiceCharge varchar(20)=null,
								@PackingCharge varchar(20)=null,
								@CuttingCharge varchar(20)=null,
								@OtherCharges varchar(20)=null,
								@RoundOff varchar(5)=null,
								@NetAmt varchar(20)=null,
								@Currency varchar(20)=null,
								@CreatedBy int =0,
								@IsApproved bit=0,
								@Year varchar(20)=null,
								@PurchaseOrderSub PurchaseOrderSub READONLY,
								@SearchString VARCHAR(200)=NULL,
								@FirstRec INT =0,
								@LastRec INT =0,
								@DisplayStart INT =0,
								@DisplayLength INT =0,
								@Sortcol INT =0,
								@SortDir varchar(10)=null,
								@ViewKey varchar(10)=null
								)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertPurchaseOrder'
BEGIN
    IF @POId=0
	BEGIN
	     SET @POId=isnull((SELECT TOP 1 POId+1 FROM PurchaseOrderMain ORDER BY POId DESC),1);
		 SET @PONo=( select + cast(CurrentNumber as varchar) + format   from SerialNoFormats where type='PurchaseOrder'  and year=@Year)
	     UPDATE SerialNoFormats set CurrentNumber=CurrentNumber+1 where type='PurchaseOrder' and year=@Year;
		 SET @IsApproved=1;
	END
	ELSE
	BEGIN
	     UPDATE PurchaseOrderMain SET IsActive=0 WHERE POId=@POId;
	     UPDATE PurchaseOrderSub SET IsActive=0 WHERE POId=@POId;
	END
	   INSERT INTO PurchaseOrderMain	
									(
									POId,
									PONo,
									Date,
								    ValidDate,
									SupplierId,
									TermsId,
									PaymentTermsId,
									DespatchThrough,
									RequiredByDate,
									PreparedBy,
									TotalAmt,
									TaxAmt,
									FreightId,
									FreightAmt,
									ServiceCharge,
									PackingCharge,
									CuttingCharge,
									OtherCharges,
									RoundOff,
									NetAmt,
									Currency,
									IsApproved,
									CreatedBy
									)
							VALUES
								  (
								  @PoId,
								  @PONo,
								  @Date,
								  @ValidDate,
								  @SupplierId,
								  @TermsId,
								  @PaymentTermsId,
								  @DespatchThrough,
								  @RequiredByDate,
								  @PreparedBy,
								  @TotalAmt,
								  @TaxAmt,
								  @FreightId,
								  @FreightAmt,
								  @ServiceCharge,
								  @PackingCharge,
								  @CuttingCharge,
								  @OtherCharges,
								  @RoundOff,
								  @NetAmt,
								  @Currency,
								  @IsApproved,
								  @CreatedBy
								  )
	   INSERT INTO PurchaseOrderSub
									(
									POId,
									ItemId,
									Qty,
									GrnBalQty,
									Rate,
									DiscPercent,
									DiscountAmt,
									NetRate,
									TaxId,
									TaxAmt,
									Amount,
									SpecificationRemarks,
									CreatedBy
									)
							SELECT  @POId,
									ItemId,
									Qty,
									Qty,
									Rate,
									DiscPercent,
									DiscountAmt,
									NetRate,
									TaxId,
									TaxAmt,
									Amount,
									SpecificationRemarks,
									@CreatedBy FROM @PurchaseOrderSub;
					SELECT '1'
						      
							
END
ELSE IF @Action='GetPurchaseOrderDtls'
BEGIN
Select * into  #POGRN from  (	Select distinct GS.POId from POGRNSub GS where GS.IsActive=1 )A
     Set @FirstRec=@DisplayStart;
     Set @LastRec=@DisplayStart+@DisplayLength;

	     select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.POId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.PONo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Date	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Supplier end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.ValidDate	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.ValidDate end desc			    
                     ) as RowNum  
					 from (								
						Select PO.POId, PO.PONo, PO.Date,C.CustomerName as Supplier,PO.ValidDate,
						case when G.POId is  null then 'false' else 'true' end as Status,
						COUNT(*) over() as TotalCount  from PurchaseOrderMain  PO
						inner join CustomerMaster C on C.CustomerId =PO.SupplierId and C.IsActive=1 
						left join #POGRN G on G.POId =  PO.POId
						where PO.IsActive=1 and (@ViewKey='View' or PO.IsApproved=0)
						
				
						  )A where (@SearchString is null or A.PONo like '%' +@SearchString+ '%' or
									A.Date like '%' +@SearchString+ '%' or A.Supplier like '%' +@SearchString+ '%' or
									A.ValidDate like '%' + @SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetPurchaseOrderDtlsById'
BEGIN
     Select POId,PONo,Date,ValidDate,SupplierId,TermsId,PaymentTermsId,DespatchThrough,RequiredByDate,PreparedBy,TotalAmt,TaxAmt,FreightId,FreightAmt,
	 ServiceCharge,     PackingCharge,CuttingCharge,OtherCharges, RoundOff,NetAmt,Currency From PurchaseOrderMain
	  Where POId=@POId AND IsActive=1

	Select R.POId,R.ItemId,I.PartNo +'-'+I.Description as ItemName, R.Qty,U.UnitName,R.Rate,R.DiscPercent,R.DiscountAmt,R.NetRate,R.TaxId,
	R.TaxAmt,R.Amount,R.SpecificationRemarks From PurchaseOrderSub R
	INNER JOIN ItemMaster I ON I.ItemId = R.ItemId AND I.IsActive=1
	inner join UnitMaster U on U.UnitId=I.UOMId and U.IsActive=1
	Where R.POId=@POId AND R.IsActive=1
END

ELSE IF @Action='ApproveStorePo'
BEGIN
   UPDATE PurchaseOrderMain SET IsApproved=1 WHERE POId=@POId AND IsActive=1 ;
   Select 1
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[PurchaseReturnSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[PurchaseReturnSP]
								(
								@Action varchar(75)=null,
								@PurchaseReturnId int =0,
								@GRNId int =0,
								@AccountingYear varchar(20)=null,
								@InvoiceNo varchar(20)=null,
								@InvoiceDate varchar(20)=null,
								@TransportMode varchar(50)=null,
								@VehicleNo varchar(30)=null,
								@DateTimeOfSupply varchar(50)=null,
								@PlaceOfSupply varchar(75)=null,
								@PONo varchar(20)=null,
								@PODate varchar(20)=null,
								@DCNo varchar(20)=null,
								@DCDate varchar(20)=null,
								@POAmmendmentNo varchar(20)=null,
								@POAmmendmentDate varchar(20)=null,
								@Total varchar(20)=null,
								@TaxId int =0,
								@TaxAmt varchar(20)=null,
								@Packing_Forwarding varchar(20)=null,
								@FinalAmt varchar(20)=null,
								@ElectronicRefNo varchar(30)=null,
								@Remarks varchar(max)=null,
								@CreatedBy int =0,
								@PurchaseReturnSub PurchaseReturnSub READONLY
								)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertPurchaseReturn'
BEGIN
    SET @PurchaseReturnId =ISNULL((SELECT TOP 1 PurchaseReturnId+1 FROM PurchaseReturnMain ORDER BY PurchaseReturnId DESC  ),1);

	INSERT INTO [dbo].[PurchaseReturnMain]
								   (
								    [PurchaseReturnId]
								   ,[GRNId]
								   ,[AccountingYear]
								   ,[InvoiceNo]
								   ,[InvoiceDate]
								   ,[TransportMode]
								   ,[VehicleNo]
								   ,[DateTimeOfSupply]
								   ,[PlaceOfSupply]
								   ,[PONo]
								   ,[PODate]
								   ,[DCNo]
								   ,[DCDate]
								   ,[POAmmendmentNo]
								   ,[POAmmendmentDate]
								   ,[Total]
								   ,[TaxId]
								   ,[TaxAmt]
								   ,[Packing_Forwarding]
								   ,[FinalAmt]
								   ,[ElectronicRefNo]
								   ,[Remarks]
								   ,[CreatedBy]
								   )
						VALUES
								(
								   @PurchaseReturnId,
								   @GRNId,
								   @AccountingYear,
								   @InvoiceNo,
								   @InvoiceDate,
								   @TransportMode,
								   @VehicleNo,
								   @DateTimeOfSupply,
								   @PlaceOfSupply,
								   @PONo,
								   @PODate,
								   @DCNo,
								   @DCDate,
								   @POAmmendmentNo,
								   @POAmmendmentDate,
								   @Total,
								   @TaxId,
								   @TaxAmt,
								   @Packing_Forwarding,
								   @FinalAmt,
								   @ElectronicRefNo,
								   @Remarks,
								   @CreatedBy
								   )
			INSERT INTO [dbo].[PurchaseReturnSub]
										   (
										    [PurchaseReturnId]
										   ,[RMPOId]
										   ,[RawMaterialId]
										   ,[Specification]
										   ,[ReturnedQty]
										   ,[Rate]
										   ,[Amount]
										   ,[CreatedBy]
										   )
									SELECT  @PurchaseReturnId
										   ,[RMPOId]
										   ,[RawMaterialId]
										   ,[Specification]
										   ,[ReturnedQty]
										   ,[Rate]
										   ,[Amount]
										   ,@CreatedBy FROM @PurchaseReturnSub;
				SELECT '1'									
END
ELSE IF @Action='GetGRNDtlsForPurReturn'
BEGIN
    Select GM.GRNId,GM.RefNo,C.CustomerName as SupplierName from GRNMain GM
	inner join CustomerMaster C on c.CustomerId=GM.SupplierId and C.IsActive=1 
	where GM.IsActive=1 
END
ELSE IF @Action='GetGRNSubDtlsForPurReturn'
BEGIN
	Select GS.RMPOId,RP.RMPONo, GS.RawMaterialId, RM.CodeNo + ' - ' + RM.Description as RMDescription ,GS.RecQty  from GRNSub GS
	inner join RawMaterial RM on RM.RawMaterialId=GS.RawMaterialId and RM.IsActive=1
	inner join RMPOMain RP on RP.RMPOId=GS.RMPOId and RP.IsActive=1 
	where GS.IsActive=1 and GS.GRNId=@GRNId;
END
ELSE IF @Action='GetPurchaseReturnDtls'
BEGIN
   SELECT PM.PurchaseReturnId, GM.RefNo,PM.InvoiceNo,PM.InvoiceDate,C.CustomerName as Supplier,PM.FinalAmt  FROM PurchaseReturnMain PM
   INNER JOIN GRNMain GM on GM.GRNId=PM.GRNId and GM.IsActive=1 
   inner join CustomerMaster C on c.CustomerId=GM.SupplierId and C.IsActive=1 
   WHERE PM.IsActive=1 order by PM.PurchaseReturnId desc
END
ELSE IF @Action='GetPurchaseReturnDtlsById'
BEGIN
    SELECT PM.GRNId,PM.AccountingYear,PM.InvoiceNo,PM.InvoiceDate,PM.TransportMode,PM.VehicleNo,PM.DateTimeOfSupply,
	PM.PlaceOfSupply,PM.PONo,PM.PODate,PM.DCNo,PM.DCDate,PM.POAmmendmentNo,PM.POAmmendmentDate,PM.Total,
	PM.TaxId,PM.TaxAmt,PM.Packing_Forwarding,PM.FinalAmt,PM.ElectronicRefNo,PM.Remarks,
	C.CustomerName as Supplier
	FROM PurchaseReturnMain PM
	INNER JOIN GRNMain GM on GM.GRNId=PM.GRNId and GM.IsActive=1 
    inner join CustomerMaster C on c.CustomerId=GM.SupplierId and C.IsActive=1 
	WHERE PM.IsActive=1 AND PM.PurchaseReturnId=@PurchaseReturnId;

	SELECT PS.RMPOId,RP.RMPONo, PS.RawMaterialId,RM.CodeNo + ' - ' + RM.Description as RMDescription ,PS.Specification,
	PS.ReturnedQty, PS.Rate,PS.Amount FROM PurchaseReturnSub PS
	inner join RawMaterial RM on RM.RawMaterialId=PS.RawMaterialId and RM.IsActive=1
	inner join RMPOMain RP on RP.RMPOId=PS.RMPOId and RP.IsActive=1 	
	WHERE PS.IsActive=1 AND PS.PurchaseReturnId=@PurchaseReturnId;
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RawMaterialOpenStockSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RawMaterialOpenStockSP]
									 ( 
									 @Action varchar(75)=null,
									 @OpenStockEntryId int =0,
									 @Date varchar(20)=null,
									 @VendorId int =0,
									 @RawMaterialId int =0,
									 @Shape varchar(75)=null,
									 @MaterialId int =0,
									 @Text1 varchar(20)=null,
									 @Text2 varchar(20)=null,
									 @Text3 varchar(20)=null,
									 @Value1 varchar(20)=null,
									 @Value2 varchar(20)=null,
									 @Value3 varchar(20)=null,
									 @QtyNos varchar(20)=null,
									 @QtyKgs varchar(20)=null,
									 @UnitWeight varchar(20)=null,
									 @CreatedBy int =0,
									 @RMDimensionId int =0,
									 @Dimension VARCHAR(50)=NULL,
									 @CodeNo varchar(50)=null
									 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
 IF @Action='InsertRMOpenStock'
BEGIN

	 Set @RawMaterialId=(Select top 1  RawMaterialId from RawMaterial where MaterialId=@MaterialId and Shape=@Shape and Text1 =@Text1 
															and Text2=@Text2 and Value1=@Value1 and isnull(Value2,'')=isnull(@Value2,''))
	IF @RawMaterialId IS NULL
	BEGIN
		 SET @RawMaterialId=isnull((Select top 1 RawMaterialId+1 from RawMaterial order by RawMaterialId desc),1);
		 SET @Dimension =@Value1 +'*' +(case when @Value2='' then '' else @Value2+'*' end ) +  @Value3;
			 INSERT INTO RawMaterial
								 (
								 RawMaterialId,
								 CodeNo,
								 Description,
								 Dimension,
								 MaterialId,
								 Shape,
								 Text1,
								 Text2,
								 Text3,
								 Value1,
								 Value2,
								 Value3,
								 UOMId,
								 PurchaseRate,
								 CreatedBy
								 )
					VALUES
							  (
								 @RawMaterialId,
								 @CodeNo,
								 @CodeNo +' - ' + @Dimension,
								 @Dimension,
								 @MaterialId,
								 @Shape,
								 @Text1,
								 @Text2,
								 @Text3,
								 @Value1,
								 @Value2,
								 @Value3,
								 2,
								 '0.00'
								 ,@CreatedBy
								 )
	END
	ELSE
	BEGIN
	        UPDATE  RawMaterialOpenStock SET IsActive=0  WHERE RawMaterialId=@RawMaterialId AND Text1=@Text1 and Text2=@Text2 and Text3=@Text3 
															   and Value1=@Value1 and isnull(Value2,'')=isnull(@Value2,'')   and Value3=@Value3
															   and VendorId=@VendorId AND ISACTIVE=1
	END

    SET @OpenStockEntryId=ISNULL((SELECT TOP 1 OpenStockEntryId+1 FROM RawMaterialOpenStock ORDER BY OpenStockEntryId DESC),1);
	INSERT INTO [dbo].[RawMaterialOpenStock]
							   ([OpenStockEntryId]
							   ,[Date]
							   ,[VendorId]
							   ,[RawMaterialId]
							   ,[Text1]
							   ,[Text2]
							   ,[Text3]
							   ,[Value1]
							   ,[Value2]
							   ,[Value3]
							   ,[QtyNos]
							   ,[CreatedBy]
							   )
					VALUES
							  (
							  @OpenStockEntryId,
							  @Date,
							  @VendorId,
							  @RawMaterialId,
							  @Text1,
							  @Text2,
							  @Text3,
							  @Value1,
							  @Value2,
							  @Value3,
							  @QtyNos,
							  @CreatedBy
							  )
   SET @RMDimensionId=(Select RMDimensionId from RMDimensionWiseStock where rawMaterialId=@rawMaterialId and materialId=@materialId and 
					shape=@shape and text1= @text1 and text2=@text2  and text3=@text3 and value1=@value1 and isnull(Value2,'')=isnull(@Value2,'')
					and value3=@value3 and VendorId=@VendorId)
	IF @RMDimensionId IS NULL
	BEGIN
	      SET @RMDimensionId=ISNULL((select top 1 RMDimensionId +1 from RMDimensionWiseStock where IsActive=1  order by RMDimensionId desc),1)	    
	END
	ELSE
	BEGIN
	     UPDATE RMDimensionWiseStock SET IsActive=0 WHERE RMDimensionId=@RMDimensionId AND IsActive=1 
	END
	  
INSERT INTO [dbo].[RMDimensionWiseStock]
						   (
						   [RMDimensionId]
						   ,[VendorId]
						   ,[RawMaterialId]
						   ,[MaterialId]
						   ,[Shape]
						   ,[Text1]
						   ,[Text2]
						   ,[Text3]
						   ,[Value1]
						   ,[Value2]
						   ,[Value3]
						   ,[UnitWeight]
						   ,[QtyNos]
						   ,[QtyKgs]
						   ,[CreatedBy]
		                  )
				VALUES
						  (
						  @RMDimensionId,
						  @VendorId,
						  @RawMaterialId, 
						  @MaterialId,
						  @Shape,
						  @Text1,
						  @Text2,
						  @Text3,
						  @Value1,
						  @Value2,
						  @Value3,
						  @UnitWeight,
						  @QtyNos,
						  @QtyKgs,
						  @CreatedBy
						  )

					SELECT '1'
END
ELSE IF @Action='GetRMOpenStockDtls'
BEGIN
		SELECT RO.Date, RM.CodeNo, RM.Description,RM.Shape, RM.Dimension,RO.QtyNos   FROM RawMaterialOpenStock RO
		inner join RawMaterial RM on RM.RawMaterialId=RO.RawMaterialId and RM.IsActive=1 
		where RO.IsActive=1 and RO.VendorId=0
		order by RO.OpenStockEntryId desc
END


COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RawMaterialSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RawMaterialSP]
                              (
							  @Action varchar(75)=null,
							  @RawMaterialId int =0,
							  @CodeNo varchar(50)=null,
							  @Description varchar(75)=null,
							  @Dimension varchar(50)=null,
							  @MaterialId int =0,
							  @Shape varchar(75)=null,
							  @Text1 varchar(30)=null,
							  @Text2 varchar(30)=null,
							  @Text3 varchar(30)=null,
							  @Value1 varchar(20)=null,
							  @Value2 varchar(20)=null,
							  @Value3 varchar(20)=null,
							  @UOMId int =0,
							  @PurchaseRate varchar(20)=null,
							  @CreatedBy int =0,
							  @SearchString VARCHAR(200)=NULL,
								@FirstRec INT =0,
								@LastRec INT =0,
								@DisplayStart INT =0,
								@DisplayLength INT =0,
								@Sortcol INT =0,
								@SortDir varchar(10)=null,
								@RequestRMId int =0
							  )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action ='InsertRawMaterial'
BEGIN
    IF @RawMaterialId=0
	BEGIN
	    SET @RawMaterialId=isnull((Select top 1 RawMaterialId+1 from RawMaterial order by RawMaterialId desc),1)
	END
	ELSE
	BEGIN
	   UPDATE RawMaterial SET IsActive=0 WHERE RawMaterialId=@RawMaterialId;
	END
	   INSERT INTO RawMaterial
	                         (
							 RawMaterialId,
							 CodeNo,
							 Description,
							 Dimension,
							 MaterialId,
							 Shape,
							 Text1,
							 Text2,
							 Text3,
							 Value1,
							 Value2,
							 Value3,
							 UOMId,
							 PurchaseRate,
							 CreatedBy
							 )
				VALUES
				          (
						     @RawMaterialId,
							 @CodeNo,
							 @Description,
							 @Dimension,
							 @MaterialId,
							 @Shape,
							 @Text1,
							 @Text2,
							 @Text3,
							 @Value1,
							 @Value2,
							 @Value3,
							 @UOMId,
							 @PurchaseRate,
							 @CreatedBy

							 )
	   IF @RequestRMId<>0
	   BEGIN
	      UPDATE NewRMRequest SET Status='Closed' where RequestRMId=@RequestRMId;
	   END
				SELECT '1'
END

IF @Action ='GetRawMaterial'
BEGIN

Set @FirstRec=@DisplayStart;
	Set @LastRec=@DisplayStart+@DisplayLength;
			select * from (
						Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
									 case when @Sortcol=0 then A.RawMaterialId end  desc,
									case when (@SortCol =1 and  @SortDir ='asc')  then A.CodeNo	end asc,
									case when (@SortCol =1 and  @SortDir ='desc') then A.CodeNo	end desc ,
									case when (@SortCol =2 and  @SortDir ='asc')  then A.Description	end asc,
									case when (@SortCol =2 and  @SortDir ='desc') then A.Description	end desc,
									case when (@SortCol =3 and  @SortDir ='asc')  then A.materialName end asc,
									case when (@SortCol =3 and  @SortDir ='desc') then A.materialName end desc,
									case when (@SortCol =4 and  @SortDir ='asc')  then A.Shape	end asc,
									case when (@SortCol =4 and  @SortDir ='desc') then A.Shape end desc,	
									 case when (@SortCol =5 and  @SortDir ='asc')  then A.Dimension end asc,
									case when (@SortCol =5 and  @SortDir ='desc') then A.Dimension end desc				    
							) as RowNum  
							from (				
							select  R.RawMaterialId,R.CodeNo,R.Description,M.materialName,R.Shape,R.Dimension,COUNT(*) over() as TotalCount from RawMaterial R
							inner join MaterialMaster M on M.materialId=R.MaterialId and M.isactive=1
							where R.isactive=1  )A 
							where 
							(@SearchString is null
							 or A.CodeNo like '%'  +@SearchString+ '%' or
							A.Description like '%' +@SearchString+ '%' or A.materialName like '%' +@SearchString+ '%' or
							A.Shape like '%' + @SearchString+ '%' or A.Dimension like '%' +@SearchString+ '%')
				) A where  RowNum > @FirstRec and RowNum <= @LastRec 
   

END


IF @Action ='GetRawMaterialById'
BEGIN

select 
 RawMaterialId,CodeNo,Description,Shape,Dimension ,MaterialId,Text1,Text2,Text3,Value1,Value2,Value3,UOMId,PurchaseRate
 from RawMaterial  where isactive=1 and RawMaterialId=@RawMaterialId

 END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RejectionReasonSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RejectionReasonSP]
                             (
							 @Action varchar(50)=null,
							 @RejectionReasonId int =0,
							 @Rejection varchar(100)=null,
							 @CreatedBy int =0
							 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertRejectionReason'
BEGIN
     IF @RejectionReasonId =0
	 BEGIN
	   SET @RejectionReasonId=IsNull((SELECT TOP 1 RejectionReasonId+1 FROM RejectionReason ORDER BY RejectionReasonId desc),1)
	 END
	 ELSE
	 BEGIN
	    UPDATE RejectionReason SET isActive=0 WHERE RejectionReasonId=@RejectionReasonId
	 END
	    INSERT INTO RejectionReason
								(
								RejectionReasonId,
								Rejection,
								CreatedBy
								)
						VALUES
							  (
							  @RejectionReasonId,
							  @Rejection,
							  @CreatedBy 
							  )
						SELECT '1'							
END
ELSE IF @Action='GetRejectionReason'
BEGIN
     SELECT RejectionReasonId, Rejection FROM RejectionReason WHERE isActive=1 ORDER BY RejectionReasonId DESC

END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[ReportsSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[ReportsSP]
		(
		@Action varchar(75)=null,
		@VendorId int = 0,
		@RawMaterialId int = 0,
		@Type varchar(20) = null,
		@ItemId int = 0,
		--Optimized Query
		@FirstRec int=0,
		@SortDir varchar(10)=null,
		@SearchString varchar(200)=null,
		@DisplayStart int=0,
		@DisplayLength int=0,
		@SortCol int=0,
		@LastRec int=0,
		@FromDate varchar(20)=null,
		@ToDate varchar(20)=null,
		@POType varchar(20)=null,		
		@SupplierId int=0,
		@Date varchar(20)=null,
		@EmpId int =0,
		@MachineId int=0,
		@PrePOId int =0,
		@DCId int =0,
		@RouteEntryId int =0,
		@EmployeeId int =0,
		@NotificationId int =0,
		@Status varchar(20)=null,
		@FirstPieceInsId int =0
		)
As

BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='ItemStore'
BEGIN
	Select IT.ItemTypeName,I.PartNo,I.Description,U.UnitName
	from ItemMaster I
	INNER JOIN ItemTypeMaster IT ON IT.ItemTypeId = I.ItemTypeId AND IT.IsActive=1
	INNER JOIN UnitMaster U ON U.UnitId=I.UOMId AND U.IsActive=1
	WHERE I.IsActive=1
END

ELSE IF @Action = 'GetItemWearStk'
BEGIN
     SET @FirstRec=@DisplayStart;
	 SET @LastRec=@DisplayStart+@DisplayLength;
     
	 SELECT * FROM(
	 	SELECT*, COUNT(*) OVER() AS filteredCount,ROW_NUMBER() OVER 
	    (ORDER BY
					CASE WHEN   @SortCol = 0  THEN A.ItemId END ASC,
					CASE WHEN   @SortCol = 0  THEN A.ItemId END DESC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='asc')  THEN A.PartNo END ASC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='desc') THEN A.PartNo END DESC,
					CASE WHEN (@SortCol = 2 and  @SortDir ='asc')  THEN A.Description END ASC,
				    CASE WHEN (@SortCol = 2 and  @SortDir ='desc') THEN A.Description END DESC,
					CASE WHEN (@SortCol = 3 and  @SortDir ='asc')  THEN A.Qty END ASC,
					CASE WHEN (@SortCol = 3 and  @SortDir ='desc') THEN A.Qty END DESC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='asc')  THEN A.Status END ASC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='desc') THEN A.Status END DESC ) as RowNum FROM(
						
				    SELECT I.ItemId,I.PartNo,I.Description,W.Qty,W.Status,COUNT(*) OVER()  AS TotalCount
					FROM Wear_DamagedItemStock W
                    INNER JOIN ItemMaster I ON W.ItemId = I.ItemId and I.IsActive = 1
                    WHERE W.IsActive = 1
					)A
		
					WHERE (@SearchString IS NULL OR
					A.ItemId LIKE '%' +@SearchString+ '%' OR
					A.PartNo LIKE '%' +@SearchString+ '%' OR
					A.Description LIKE '%' +@SearchString+ '%' OR
					A.Qty LIKE '%' +@SearchString+ '%' OR
					A.Status LIKE '%' +@SearchString+ '%' ))B
					where  RowNum > @FirstRec and RowNum <= @LastRec

END

ELSE IF @Action = 'GetVendorWiseStk'
BEGIN
     SET @FirstRec=@DisplayStart;
	 SET @LastRec=@DisplayStart+@DisplayLength;
     
	 SELECT * FROM(
	 	SELECT*, COUNT(*) OVER() AS filteredCount,ROW_NUMBER() OVER 
	    (ORDER BY
					CASE WHEN   @SortCol = 0  THEN A.RawMaterialId END ASC,
					CASE WHEN   @SortCol = 0  THEN A.RawMaterialId END DESC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='asc')  THEN A.CustomerName END ASC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='desc') THEN A.CustomerName END DESC,
					CASE WHEN (@SortCol = 2 and  @SortDir ='asc')  THEN A.CodeNo END ASC,
				    CASE WHEN (@SortCol = 2 and  @SortDir ='desc') THEN A.CodeNo END DESC,
					CASE WHEN (@SortCol = 3 and  @SortDir ='asc')  THEN A.Description END ASC,
				    CASE WHEN (@SortCol = 3 and  @SortDir ='desc') THEN A.Description END DESC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='asc')  THEN A.QtyKgs END ASC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='desc') THEN A.QtyKgs END DESC,
					CASE WHEN (@SortCol = 5 and  @SortDir ='asc')  THEN A.QtyNos END ASC,
					CASE WHEN (@SortCol = 5 and  @SortDir ='desc') THEN A.QtyNos END DESC ) as RowNum FROM(
						
				    SELECT R.RawMaterialId,R.VendorId,C.CustomerName,RM.CodeNo,RM.Description,SUM(CAST(R.QtyKgs AS decimal(18,2)) ) AS 'QtyKgs',
					SUM(CAST(R.QtyNos AS decimal(18,2)) ) AS 'QtyNos',COUNT(*) OVER()  AS TotalCount
					FROM RMDimensionWiseStock R
					INNER JOIN CustomerMaster C ON R.VendorId = C.CustomerId AND C.CustomerType = 'Vendor' AND C.IsActive = 1 
					INNER JOIN RawMaterial RM ON R.RawMaterialId = RM.RawMaterialId And RM.Isactive = 1
					WHERE R.IsActive = 1 AND R.VendorId <> 0 AND (@VendorId = 0 or R.VendorId = @VendorId)
					GROUP BY R.RawMaterialId,R.VendorId,C.CustomerName,RM.CodeNo,RM.DESCRIPTION
					)A
		
					WHERE (@SearchString IS NULL OR
					A.RawMaterialId LIKE '%' +@SearchString+ '%' OR
					A.CustomerName LIKE '%' +@SearchString+ '%' OR
					A.CodeNo LIKE '%' +@SearchString+ '%' OR
					A.Description LIKE '%' +@SearchString+ '%' OR
					A.QtyNos LIKE '%' +@SearchString+ '%' OR
					A.QtyKgs LIKE '%' +@SearchString+ '%' ))B
					where  RowNum > @FirstRec and RowNum <= @LastRec

END


ELSE IF @Action = 'GetRMDimenstionStk'
BEGIN
     SET @FirstRec=@DisplayStart;
	 SET @LastRec=@DisplayStart+@DisplayLength;
     
	 SELECT * FROM(
	 	SELECT*, COUNT(*) OVER() AS filteredCount,ROW_NUMBER() OVER 
	    (ORDER BY
					CASE WHEN   @SortCol = 0  THEN A.RawMaterialId END ASC,
					CASE WHEN   @SortCol = 0  THEN A.RawMaterialId END DESC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='asc')  THEN A.CodeNo END ASC,
				    CASE WHEN (@SortCol = 1 and  @SortDir ='desc') THEN A.CodeNo END DESC,
					CASE WHEN (@SortCol = 2 and  @SortDir ='asc')  THEN A.Description END ASC,
				    CASE WHEN (@SortCol = 2 and  @SortDir ='desc') THEN A.Description END DESC,
					CASE WHEN (@SortCol = 3 and  @SortDir ='asc')  THEN A.MaterialName END ASC,
					CASE WHEN (@SortCol = 3 and  @SortDir ='desc') THEN A.MaterialName END DESC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='asc')  THEN A.Shape END ASC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='desc') THEN A.Shape END DESC, 
					CASE WHEN (@SortCol = 5 and  @SortDir ='asc')  THEN A.Dimension END ASC,
					CASE WHEN (@SortCol = 5 and  @SortDir ='desc') THEN A.Dimension END DESC,					
					CASE WHEN (@SortCol = 6 and  @SortDir ='asc')  THEN A.UnitWeight END ASC,
					CASE WHEN (@SortCol = 6 and  @SortDir ='desc') THEN A.UnitWeight END DESC,					
					CASE WHEN (@SortCol = 7 and  @SortDir ='asc')  THEN A.QtyNos END ASC,
					CASE WHEN (@SortCol = 7 and  @SortDir ='desc') THEN A.QtyNos END DESC,					
					CASE WHEN (@SortCol = 8 and  @SortDir ='asc')  THEN A.QtyKgs END ASC,
					CASE WHEN (@SortCol = 8 and  @SortDir ='desc') THEN A.QtyKgs END DESC
					) as RowNum FROM(
						
					SELECT RM.RawMaterialId,R.VendorId,C.CustomerName,RM.CodeNo,RM.Description,M.MaterialName,R.Shape,
					R.Text1 +'-' + R.Value1 + CASE WHEN R.Text2 <>'' AND  R.Text2 IS NOT NULL THEN ' * ' + R.Text2 + '-' + R.Value2 + ' * ' ELSE ' * ' END + R.Text3 + '-' + R.Value3 AS 'Dimension',
					R.UnitWeight,R.QtyNos,R.QtyKgs,COUNT(*) OVER()  AS TotalCount
					FROM RMDimensionWiseStock R
					left JOIN CustomerMaster C ON R.VendorId = C.CustomerId AND C.CustomerType = 'Vendor' AND C.IsActive = 1 
					INNER JOIN RawMaterial RM ON R.RawMaterialId = RM.RawMaterialId AND RM.Isactive = 1
					INNER JOIN MaterialMaster M ON M.materialId = R.MaterialId AND M.Isactive =1
					WHERE R.IsActive = 1 AND
					@RawMaterialId in (0,R.RawMaterialId) and R.VendorId=@VendorId	
					)A
		
					WHERE (@SearchString IS NULL OR
					A.RawMaterialId LIKE '%' +@SearchString+ '%' OR
					A.CodeNo LIKE '%' +@SearchString+ '%' OR
					A.Description LIKE '%' +@SearchString+ '%' OR
					A.MaterialName LIKE '%' +@SearchString+ '%' OR
					A.Shape LIKE '%' +@SearchString+ '%' OR
					A.Dimension LIKE '%' +@SearchString+ '%' OR
					A.UnitWeight LIKE '%' +@SearchString+ '%' OR
					A.QtyNos LIKE '%' +@SearchString+ '%' OR
					A.QtyKgs LIKE '%' +@SearchString+ '%' ))B
					where  RowNum > @FirstRec and RowNum <= @LastRec

END


ELSE IF @Action = 'GetWearStkLst'
BEGIN
     SET @FirstRec=@DisplayStart;
	 SET @LastRec=@DisplayStart+@DisplayLength;
     
	 SELECT * FROM(
	 	SELECT*, COUNT(*) OVER() AS filteredCount,ROW_NUMBER() OVER 
	    (ORDER BY
					CASE WHEN   @SortCol = 0  THEN A.ItemId END ASC,
					CASE WHEN   @SortCol = 0  THEN A.ItemId END DESC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='asc')  THEN A.PartNo END ASC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='desc') THEN A.PartNo END DESC,
					CASE WHEN (@SortCol = 2 and  @SortDir ='asc')  THEN A.Description END ASC,
				    CASE WHEN (@SortCol = 2 and  @SortDir ='desc') THEN A.Description END DESC,
					CASE WHEN (@SortCol = 3 and  @SortDir ='asc')  THEN A.Type END ASC,
				    CASE WHEN (@SortCol = 3 and  @SortDir ='desc') THEN A.Type END DESC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='asc')  THEN A.Qty END ASC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='desc') THEN A.Qty END DESC
					) as RowNum FROM(
						
					SELECT I.ItemId,I.PartNo,I.Description,MS.Type,SUM (CAST(MS.Qty AS INT )) AS 'Qty',COUNT(*) OVER()  AS TotalCount
					FROM MaterialOutInwardSub MS
					INNER JOIN ItemMaster I ON I.ItemId = MS.ItemId AND I.IsActive = 1
					WHERE MS.IsActive = 1
					AND (@Type = '' OR MS.Type = @Type)
					GROUP BY I.ItemId,I.PartNo,I.Description,MS.Type

					)A		
					WHERE (@SearchString IS NULL OR
					A.ItemId LIKE '%' +@SearchString+ '%' OR
					A.PartNo LIKE '%' +@SearchString+ '%' OR
					A.Description LIKE '%' +@SearchString+ '%' OR
					A.Type LIKE '%' +@SearchString+ '%' OR
					A.Qty LIKE '%' +@SearchString+ '%' ))B
					where  RowNum > @FirstRec and RowNum <= @LastRec

END


ELSE IF @Action = 'GetInwardWiseWearStkLst'
BEGIN
     SET @FirstRec=@DisplayStart;
	 SET @LastRec=@DisplayStart+@DisplayLength;
     
	 SELECT * FROM(
	 	SELECT*, COUNT(*) OVER() AS filteredCount,ROW_NUMBER() OVER 
	    (ORDER BY
					CASE WHEN   @SortCol = 0  THEN A.InwardId END ASC,
					CASE WHEN   @SortCol = 0  THEN A.InwardId END DESC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='asc')  THEN A.InwardNo END ASC,
					CASE WHEN (@SortCol = 1 and  @SortDir ='desc') THEN A.InwardNo END DESC,
					CASE WHEN (@SortCol = 2 and  @SortDir ='asc')  THEN A.InwardDate END ASC,
				    CASE WHEN (@SortCol = 2 and  @SortDir ='desc') THEN A.InwardDate END DESC,
					CASE WHEN (@SortCol = 3 and  @SortDir ='asc')  THEN A.CustomerName END ASC,
				    CASE WHEN (@SortCol = 3 and  @SortDir ='desc') THEN A.CustomerName END DESC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='asc')  THEN A.Qty END ASC,
					CASE WHEN (@SortCol = 4 and  @SortDir ='desc') THEN A.Qty END DESC
					) as RowNum FROM(
										
					SELECT	MM.InwardId,MM.InwardNo,MM.InwardDate,CM.CustomerId,CM.CustomerName,MS.Type,
					MS.Qty,MS.ItemId,I.PartNo,I.Description, COUNT(*) OVER()  AS TotalCount
					FROM  MaterialOutInwardSub MS
					INNER JOIN MaterialOutInwardMain MM ON MM.InwardId = MS.InwardId AND MM.IsActive = 1
					INNER JOIN CustomerMaster CM ON MM.CustomerId = CM.CustomerId AND CM.IsActive = 1
					INNER JOIN ItemMaster I ON I.ItemId = MS.ItemId AND I.IsActive = 1
					WHERE MS.IsActive = 1 AND  MS.ItemId = @ItemId AND MS.TYPE = @Type										

					)A		
					WHERE (@SearchString IS NULL OR
					A.InwardId LIKE '%' +@SearchString+ '%' OR
					A.InwardNo LIKE '%' +@SearchString+ '%' OR
					A.InwardDate LIKE '%' +@SearchString+ '%' OR
					A.CustomerName LIKE '%' +@SearchString+ '%' OR
					A.Qty LIKE '%' +@SearchString+ '%' ))B
					where  RowNum > @FirstRec and RowNum <= @LastRec

END

ELSE IF @Action='GetMaterialOutDCDtlsByDate_Vendor'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.DCId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.POType  end asc,
					case when (@SortCol =1 and  @SortDir ='desc') then A.POType end desc,
					case when (@SortCol =2 and  @SortDir ='asc')  then A.DCNo  end asc,
				    case when (@SortCol =2 and  @SortDir ='desc') then A.DCNo  end desc, 
				    case when (@SortCol =3 and  @SortDir ='asc')  then A.DCDate  end asc,
					case when (@SortCol =3 and  @SortDir ='desc')  then A.DCDate end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.VendorName  end asc,
					case when (@SortCol =4 and  @SortDir ='desc') then A.VendorName end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.B_GSTNo  end asc,
				    case when (@SortCol =5 and  @SortDir ='desc')then A.B_GSTNo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.DespatchThrough  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.DespatchThrough end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.RequireByDate  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.RequireByDate end desc
					)as RowNum from(
						Select D.DCId, D.POType,D.DCNo, CONVERT(varchar,cast(D.DCDate as date),105) as DCDate,
						C.CustomerName as VendorName,CA.B_GSTNo,D.DespatchThrough,
						 case when RequireByDate <>'' then  CONVERT(varchar,cast(D.RequireByDate as date),105) end as RequireByDate,
						COUNT(*) over() as TotalCount from DCEntryMain D
						inner join CustomerMaster C on C.CustomerId=D.SupplierId and C.IsActive=1 
						left join CustAddressDtls CA on CA.CustomerId=D.SupplierId and CA.IsActive=1 
						where D.IsActive=1 and @VendorId in (0,D.SupplierId) 
						and CAST(D.DCDate as date) between cast(@FromDate as date) and CAST(@ToDate as date) and @POType in ('',D.POType)
			          ) A 
					 where (@SearchString is null or
							A.POType like '%' +@SearchString + '%' or
							A.DCNo like '%' +@SearchString+ '%' or
							A.DCDate like '%' +@SearchString+ '%' or
							A.VendorName like '%' +@SearchString + '%' or
							A.B_GSTNo like '%'+@SearchString + '%' or
			                A.DespatchThrough like '%'+@SearchString + '%'or
							A.RequireByDate like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec

END
ELSE IF @Action='GetInwardDCDtlsByDate_Vendor'
BEGIN
       SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.InwardDCId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.POType  end asc,
					case when (@SortCol =1 and  @SortDir ='desc') then A.POType end desc,
					case when (@SortCol =2 and  @SortDir ='asc')  then A.InwardDCNo  end asc,
				    case when (@SortCol =2 and  @SortDir ='desc') then A.InwardDCNo  end desc, 
				    case when (@SortCol =3 and  @SortDir ='asc')  then A.InwardDCDate  end asc,
					case when (@SortCol =3 and  @SortDir ='desc')  then A.InwardDCDate end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.VendorName  end asc,
					case when (@SortCol =4 and  @SortDir ='desc') then A.VendorName end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.VendorDCNo  end asc,
				    case when (@SortCol =5 and  @SortDir ='desc')then A.VendorDCNo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.VendorDCDate  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.VendorDCDate end desc
					)as RowNum from(
						Select IM.InwardDCId,IM.POType,IM.InwardDCNo,CONVERT(varchar,cast(IM.InwardDCDate as date),105) as InwardDCDate,
						C.CustomerName as VendorName,IM.VendorDCNo,
						case when IM.VendorDCDate <>'' then  CONVERT(varchar,cast(IM.VendorDCDate as date),105) end as VendorDCDate, 
						COUNT(*) over() as TotalCount  from InwardDCMain IM
						inner join CustomerMaster C on C.CustomerId=IM.VendorId and C.IsActive=1 
						where IM.IsActive=1 and @VendorId in (0,IM.VendorId) 
						and CAST(IM.InwardDCDate as date) between cast(@FromDate as date) and CAST(@ToDate as date) and @POType in ('',IM.POType)
			         ) A 
					 where (@SearchString is null or
							A.POType like '%' +@SearchString + '%' or
							A.InwardDCNo like '%' +@SearchString+ '%' or
							A.InwardDCDate like '%' +@SearchString+ '%' or
							A.VendorName like '%' +@SearchString + '%' or
							A.VendorDCNo like '%'+@SearchString + '%' or
			                A.VendorDCDate like '%'+@SearchString + '%'
						))B where  RowNum > @FirstRec and RowNum <= @LastRec
END
ELSE IF @Action='GetAllPODtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

	Select * into  #GRN from  (	Select distinct GS.RMPOId from GRNSub GS where GS.IsActive=1 )A
	Select * into  #POGRN from  (	Select distinct GS.POId from POGRNSub GS where GS.IsActive=1 )A

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.POId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.PONo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Date	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Supplier end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.Terms	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.Terms end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PaymentTerm end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PaymentTerm end desc				    
                     ) as RowNum  
					 from (	
					 Select *,COUNT(*) over() as TotalCount from(							
						Select 'RMPO' as POType, RM.RMPOID as POId, RM.RMPONo as PONo , CONVERT(varchar,cast(RM.Date as date),105) as Date, C.CustomerName as Supplier , T.Terms , P.PaymentTerm , 
						case when G.RMPOId is  null then 'false' else 'true' end as Status
						from RMPOMain RM
						inner join CustomerMaster C on C.CustomerId=RM.SupplierId and C.IsActive=1 
						left join Terms_ConditionMaster T on T.TermsId=RM.TermsId and T.IsActive=1
						left join PaymentTerms P on P.PaymentId=RM.PaymentTermsId and P.IsActive=1
						left join #GRN G on G.RMPOId =  RM.RMPOId 
						where RM.IsActive=1 and @SupplierId in (0,RM.SupplierId) 
						and CAST(RM.Date as date) between cast(@FromDate as date) and CAST(@ToDate as date)
						union all
						Select 'StorePO' as POType, PO.POId, PO.PONo, CONVERT(varchar,cast(PO.Date as date),105) as Date,C.CustomerName as Supplier,T.Terms , P.PaymentTerm , 
						case when G.POId is  null then 'false' else 'true' end as Status
					    from PurchaseOrderMain  PO
						inner join CustomerMaster C on C.CustomerId =PO.SupplierId and C.IsActive=1 
						left join Terms_ConditionMaster T on T.TermsId=PO.TermsId and T.IsActive=1
						left join PaymentTerms P on P.PaymentId=PO.PaymentTermsId and P.IsActive=1
						left join #POGRN G on G.POId =  PO.POId
						where PO.IsActive=1  and @SupplierId in (0,PO.SupplierId) 
						and CAST(PO.Date as date) between cast(@FromDate as date) and CAST(@ToDate as date)

						 ) A)A where (@SearchString is null or A.PONo like '%' +@SearchString+ '%' or
									A.Date like '%' +@SearchString+ '%' or A.Supplier like '%' +@SearchString+ '%' or
									A.Terms like '%' + @SearchString+ '%' or A.PaymentTerm like '%' +@SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetAllDCDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

	
        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DCId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.DCNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.DCNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.DCDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DCDate	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.VendorName end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.VendorName end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.NatureOfProcess	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.NatureOfProcess end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.VehicleNo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.VehicleNo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.DeliverySchedule end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.DeliverySchedule end desc			    
                     ) as RowNum  
					 from (	
					 Select *,COUNT(*) over() as TotalCount from(							
						Select 'VendorDC' as DCType, D.DCId,D.DCNo,CONVERT(varchar,cast(D.DCDate as date),105) as DCDate,
						C.CustomerName as VendorName,D.NatureOfProcess,D.VehicleNo,	D.DeliverySchedule
						 from DCEntryMain D
						inner join CustomerMaster C on C.CustomerId=D.SupplierId and C.IsActive=1 
						where D.IsActive=1  and CAST(D.DCDate as date) between cast(@FromDate as date) and CAST(@ToDate as date)
						union all
						Select 'MaterialOutDC' as DCType, MD.MaterialOutDCId as DCID,MD.MaterialOutDCNo as DCNo,CONVERT(varchar,cast(MD.Date as date),105) as DCDate,
						C.CustomerName as VendorName,MD.NatureOfProcess,MD.VehicleNo,MD.DeliverySchedule
						 from MaterialOutDCMain MD
						inner join CustomerMaster C on C.CustomerId=MD.CustomerId and C.IsActive=1 
						where MD.IsActive=1 and CAST(MD.Date as date) between cast(@FromDate as date) and CAST(@ToDate as date)

						 ) A)A where (@SearchString is null or A.DCNo like '%' +@SearchString+ '%' or
									A.DCDate like '%' +@SearchString+ '%' or A.VendorName like '%' +@SearchString+ '%' or
									A.NatureOfProcess like '%' + @SearchString+ '%' or A.VehicleNo like '%' +@SearchString+ '%' or A.DeliverySchedule like  '%' +@SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetProdReportDtls'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.DPRId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.ProdEmployee  end asc,
				    case when (@SortCol =1 and  @SortDir ='desc')then A.ProdEmployee end desc,
					case when (@SortCol =2 and  @SortDir ='asc') then A.POType  end asc,
					case when (@SortCol =2 and  @SortDir ='desc') then A.POType end desc,
					case when (@SortCol =3 and  @SortDir ='asc')  then A.PONo  end asc,
				    case when (@SortCol =3 and  @SortDir ='desc') then A.PONo  end desc, 
				    case when (@SortCol =4 and  @SortDir ='asc')  then A.RouteCardNo  end asc,
					case when (@SortCol =4 and  @SortDir ='desc')  then A.RouteCardNo end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.PartNo  end asc,
					case when (@SortCol =5 and  @SortDir ='desc') then A.PartNo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.ItemDescription  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.ItemDescription end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.Operation  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.Operation end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.Time  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.Time end desc,
					case when (@SortCol =9 and  @SortDir ='asc') then A.Qty  end asc,
				    case when (@SortCol =9 and  @SortDir ='desc')then A.Qty end desc,
					case when (@SortCol =10 and  @SortDir ='asc') then A.ContinueShift  end asc,
				    case when (@SortCol =10 and  @SortDir ='desc')then A.ContinueShift end desc
					)as RowNum from(
							Select D.DPRId, D.POType,ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,E.EmpName as ProdEmployee,
							D.Qty,D.StartTime + ' To ' + D.EndTime as Time,case when D.ContinueShift='false' then 'Yes' else '' end as ContinueShift,COUNT(*) over() as TotalCount
							from DPREntry D
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1  
							inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							where D.IsActive=1 and D.DPRKey='Production' and D.DPRDate=@Date and @POType in ('',D.POType) and @EmpId in (0,D.ProdEmpId)
			          ) A 
					 where (@SearchString is null or
							A.POType like '%' +@SearchString + '%' or
							A.PONo like '%' +@SearchString+ '%' or
							A.PartNo like '%' +@SearchString+ '%' or
							A.ItemDescription like '%' +@SearchString + '%' or
							A.RouteCardNo like '%'+@SearchString + '%' or
			                A.Operation like '%'+@SearchString + '%'or
							A.ProdEmployee like '%' +@SearchString + '%'or
							A.Qty like '%' +@SearchString + '%'or
							A.Time like '%' +@SearchString + '%'or
							A.ContinueShift like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec

END
ELSE IF @Action='GetMonthWiseProdReportDtls'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.DPRId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.DPRDate  end asc,
				    case when (@SortCol =1 and  @SortDir ='desc')then A.DPRDate end desc,
					case when (@SortCol =2 and  @SortDir ='asc') then A.ProdEmployee  end asc,
					case when (@SortCol =2 and  @SortDir ='desc') then A.ProdEmployee end desc,
					case when (@SortCol =3 and  @SortDir ='asc')  then A.POType  end asc,
				    case when (@SortCol =3 and  @SortDir ='desc') then A.POType  end desc, 
				    case when (@SortCol =4 and  @SortDir ='asc')  then A.PONo  end asc,
					case when (@SortCol =4 and  @SortDir ='desc')  then A.PONo end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.RouteCardNo  end asc,
					case when (@SortCol =5 and  @SortDir ='desc') then A.RouteCardNo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.PartNo  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.PartNo end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.ItemDescription  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.ItemDescription end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.Operation  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.Operation end desc,
					case when (@SortCol =9 and  @SortDir ='asc') then A.Time  end asc,
				    case when (@SortCol =9 and  @SortDir ='desc')then A.Time end desc,
					case when (@SortCol =10 and  @SortDir ='asc') then A.WorkingHrs  end asc,
				    case when (@SortCol =10 and  @SortDir ='desc')then A.WorkingHrs end desc,
					case when (@SortCol =11 and  @SortDir ='asc') then A.Qty  end asc,
				    case when (@SortCol =11 and  @SortDir ='desc')then A.Qty end desc,
					case when (@SortCol =12 and  @SortDir ='asc') then A.ContinueShift  end asc,
				    case when (@SortCol =12 and  @SortDir ='desc')then A.ContinueShift end desc
					)as RowNum from(
							Select D.DPRId,CONVERT(varchar,cast(D.DPRDate as date),105) as DPRDate, D.POType,ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,E.EmpName as ProdEmployee,
							D.Qty,D.StartTime + ' To ' + D.EndTime as Time,
							CONVERT(NUMERIC(18, 2), (DATEDIFF(MINUTE, D.StartTime , D.EndTime))/ 60 + ((DATEDIFF(MINUTE, D.StartTime , D.EndTime))% 60) / 100.0) as 'WorkingHrs',
							case when D.ContinueShift='false' then 'Yes' else '' end as ContinueShift,COUNT(*) over() as TotalCount
							from DPREntry D
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1  
							inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							where D.IsActive=1 and D.DPRKey='Production' and
							cast(D.DPRDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
							 and @POType in ('',D.POType) 
			          ) A 
					 where (@SearchString is null or
							A.DPRDate like '%' +@SearchString + '%' or
							A.POType like '%' +@SearchString + '%' or
							A.PONo like '%' +@SearchString+ '%' or
							A.RouteCardNo like '%'+@SearchString + '%' or
							A.PartNo like '%' +@SearchString+ '%' or
							A.ItemDescription like '%' +@SearchString + '%' or
			                A.Operation like '%'+@SearchString + '%'or
							A.ProdEmployee like '%' +@SearchString + '%'or
							A.Qty like '%' +@SearchString + '%'or
							A.Time like '%' +@SearchString + '%'or
							A.WorkingHrs like '%' +@SearchString + '%'or
							A.ContinueShift like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec

END
ELSE IF @Action='GetMachineWiseProdReportDtls'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.DPRId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.POType  end asc,
				    case when (@SortCol =1 and  @SortDir ='desc')then A.POType end desc,
					case when (@SortCol =2 and  @SortDir ='asc') then A.DPRNo  end asc,
					case when (@SortCol =2 and  @SortDir ='desc') then A.DPRNo end desc,
					case when (@SortCol =3 and  @SortDir ='asc')  then A.DPRDate  end asc,
				    case when (@SortCol =3 and  @SortDir ='desc') then A.DPRDate  end desc, 
				    case when (@SortCol =4 and  @SortDir ='asc')  then A.PONo  end asc,
					case when (@SortCol =4 and  @SortDir ='desc')  then A.PONo end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.RouteCardNo  end asc,
					case when (@SortCol =5 and  @SortDir ='desc') then A.RouteCardNo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.PartNo  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.PartNo end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.ItemDescription  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.ItemDescription end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.Operation  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.Operation end desc,
					case when (@SortCol =9 and  @SortDir ='asc') then A.Qty  end asc,
				    case when (@SortCol =9 and  @SortDir ='desc')then A.Qty end desc,
					case when (@SortCol =10 and  @SortDir ='asc') then A.ShiftName  end asc,
				    case when (@SortCol =10 and  @SortDir ='desc')then A.ShiftName end desc,
					case when (@SortCol =11 and  @SortDir ='asc') then A.MachineCode_Name  end asc,
				    case when (@SortCol =11 and  @SortDir ='desc')then A.MachineCode_Name end desc,
					case when (@SortCol =12 and @SortDir ='asc') then A.ProdEmployee  end asc,
				    case when (@SortCol =12 and  @SortDir ='desc')then A.ProdEmployee end desc,
					case when (@SortCol =13 and  @SortDir ='asc') then A.ContinueShift  end asc,
				    case when (@SortCol =13 and  @SortDir ='desc')then A.ContinueShift end desc
					)as RowNum from(
							Select D.DPRId,D.DPRNo, CONVERT(varchar,cast(D.DPRDate as date),105) as DPRDate, D.POType,ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,E.EmpName as ProdEmployee,
							D.Qty,	M.MachineCode +' - ' + M.MachineName as MachineCode_Name,S.ShiftName,						
							case when D.ContinueShift='false' then 'Yes' else '' end as ContinueShift,COUNT(*) over() as TotalCount
							from DPREntry D
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
							inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 
							inner join ShiftMaster S on S.ShiftId=D.ShiftID and S.IsActive=1 
							inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							where D.IsActive=1 and D.DPRKey='Production' and
							cast(D.DPRDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
							 and @POType in ('',D.POType)  and @MachineId in (0,D.MachineId)
			          ) A 
					 where (@SearchString is null or
							A.DPRNo like '%' +@SearchString + '%' or
							A.DPRDate like '%' +@SearchString + '%' or
							A.POType like '%' +@SearchString + '%' or
							A.PONo like '%' +@SearchString+ '%' or
							A.RouteCardNo like '%' +@SearchString+ '%' or
							A.PartNo like '%' +@SearchString+ '%' or
							A.ItemDescription like '%' +@SearchString + '%' or
			                A.Operation like '%'+@SearchString + '%'or
							A.ProdEmployee like '%' +@SearchString + '%'or
							A.ShiftName like '%' +@SearchString + '%'or
							A.MachineCode_Name like '%' +@SearchString + '%'or
							A.Qty like '%' +@SearchString + '%'or
							A.ContinueShift like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec

END

---16-12-2022
ELSE IF @Action='GetFirstPieceInspDtls'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.FirstPieceInspId   end desc,
					case when (@SortCol =2 and  @SortDir ='asc') then A.POType  end asc,
				    case when (@SortCol =2 and  @SortDir ='desc')then A.POType end desc,
				    case when (@SortCol =3 and  @SortDir ='asc')  then A.PONo  end asc,
					case when (@SortCol =3 and  @SortDir ='desc')  then A.PONo end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.RouteCardNo  end asc,
					case when (@SortCol =4 and  @SortDir ='desc') then A.RouteCardNo end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.PartNo  end asc,
				    case when (@SortCol =5 and  @SortDir ='desc')then A.PartNo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.ItemDescription  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.ItemDescription end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.MachineCode_Name  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.MachineCode_Name end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.SettingDate  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.SettingDate end desc,
					case when (@SortCol =9 and  @SortDir ='asc') then A.SettingTime  end asc,
				    case when (@SortCol =9 and  @SortDir ='desc')then A.SettingTime end desc,
					case when (@SortCol =10 and  @SortDir ='asc') then A.QCStatus  end asc,
				    case when (@SortCol =10 and  @SortDir ='desc')then A.QCStatus end desc,
					case when (@SortCol =11 and  @SortDir ='asc') then A.InspectedBy  end asc,
				    case when (@SortCol =11 and  @SortDir ='desc')then A.InspectedBy end desc,
					case when (@SortCol =12 and  @SortDir ='asc') then A.InspectedOn  end asc,
				    case when (@SortCol =12 and  @SortDir ='desc')then A.InspectedOn end desc
					)as RowNum from(
							Select  F.FirstPieceInspId,F.Attachments , D.POType,ISNULL(PM.PrePONo,JM.PONo) as PONo,D.RouteEntryId as RouteCardNo, isnull(I.PartNo,JS.PartNo) as PartNo,
							isnull(I.Description,JS.ItemName) as ItemDescription,M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
							CONVERT(varchar,cast(D.DPRDate as date),105) as SettingDate,D.StartTime + ' To ' + D.EndTime as SettingTime,
							F.QCStatus,IE.EmpName as InspectedBy,F.QCDate as InspectedOn,COUNT(*) over() as TotalCount
							 from FirstPieceInspectionMain F
							inner join DPREntry D on D.DPRId=F.DPRId and D.IsActive=1 
							inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 
							inner join EmployeeDetails IE on IE.EmpId=F.PreparedBy and IE.IsActive=1 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1								
							where F.IsActive=1 and   @POType in ('',D.POType)  and @PrePOId in (0,D.PrePoId) and @ItemId in (0,D.ItemId)
			          ) A 
					 where (@SearchString is null or
							A.POType like '%' +@SearchString + '%' or
							A.PONo like '%' +@SearchString + '%' or
							A.RouteCardNo like '%' +@SearchString + '%' or
							A.PartNo like '%' +@SearchString+ '%' or
							A.ItemDescription like '%' +@SearchString+ '%' or
							A.MachineCode_Name like '%' +@SearchString+ '%' or
			                A.SettingDate like '%'+@SearchString + '%'or
							A.SettingTime like '%' +@SearchString + '%'or
							A.QCStatus like '%' +@SearchString + '%'or
							A.InspectedBy like '%' +@SearchString + '%'or
							A.InspectedOn like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec

END
ELSE IF @Action='GetNotInMachineDtls'
BEGIN
    Select M.MachineId, M.MachineCode, M.MachineName, M.Type,M.LastCalibrationDate
	from MachineDetails M
	where M.IsActive=1 and M.Status='Active' and M.IsNotInUse='1' AND (@Type IS NULL OR M.Type=@Type)
END
ELSE IF @Action='GetMachineWiseProdHrs'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.DPRId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.POType  end asc,
				    case when (@SortCol =1 and  @SortDir ='desc')then A.POType end desc,
					case when (@SortCol =2 and  @SortDir ='asc') then A.DPRNo  end asc,
					case when (@SortCol =2 and  @SortDir ='desc') then A.DPRNo end desc,
					case when (@SortCol =3 and  @SortDir ='asc')  then A.DPRDate  end asc,
				    case when (@SortCol =3 and  @SortDir ='desc') then A.DPRDate  end desc, 
				    case when (@SortCol =4 and  @SortDir ='asc')  then A.PONo  end asc,
					case when (@SortCol =4 and  @SortDir ='desc')  then A.PONo end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.RouteCardNo  end asc,
					case when (@SortCol =5 and  @SortDir ='desc') then A.RouteCardNo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.PartNo  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.PartNo end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.ItemDescription  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.ItemDescription end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.Operation  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.Operation end desc,
					case when (@SortCol =9 and  @SortDir ='asc') then A.Qty  end asc,
				    case when (@SortCol =9 and  @SortDir ='desc')then A.Qty end desc,
					case when (@SortCol =10 and  @SortDir ='asc') then A.SettingTime  end asc,
				    case when (@SortCol =10 and  @SortDir ='desc')then A.SettingTime end desc,
					case when (@SortCol =11 and  @SortDir ='asc') then A.SettingHrs  end asc,
				    case when (@SortCol =11 and  @SortDir ='desc')then A.SettingHrs end desc,
					case when (@SortCol =12 and  @SortDir ='asc') then A.ProdTime  end asc,
				    case when (@SortCol =12 and  @SortDir ='desc')then A.ProdTime end desc,
					case when (@SortCol =13 and  @SortDir ='asc') then A.ProdHrs  end asc,
				    case when (@SortCol =13 and  @SortDir ='desc')then A.ProdHrs end desc,
					case when (@SortCol =14 and  @SortDir ='asc') then A.ContinueShift  end asc,
				    case when (@SortCol =14 and  @SortDir ='desc')then A.ContinueShift end desc
					)as RowNum from(
							Select D.DPRId,D.DPRNo, CONVERT(varchar,cast(D.DPRDate as date),105) as DPRDate, D.POType,ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,
							D.Qty,F.SetupFrom +' To ' + F.SetupTo as SettingTime,D.StartTime +' To ' + D.EndTime as ProdTime,
							CONVERT(NUMERIC(18, 2), (DATEDIFF(MINUTE, D.StartTime , D.EndTime))/ 60 + ((DATEDIFF(MINUTE, F.SetupFrom , F.SetupTo))% 60) / 100.0) as 'SettingHrs',
							CONVERT(NUMERIC(18, 2), (DATEDIFF(MINUTE, D.StartTime , D.EndTime))/ 60 + ((DATEDIFF(MINUTE, D.StartTime , D.EndTime))% 60) / 100.0) as 'ProdHrs',											
							case when D.ContinueShift='false' then 'Yes' else '' end as ContinueShift,COUNT(*) over() as TotalCount
							from DPREntry D
							inner join FirstPieceInspectionMain F on F.FirstPieceInspId=D.FirstPieceInspId and F.IsActive=1 
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							where D.IsActive=1 and D.DPRKey='Production' and
							cast(D.DPRDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
							 and @POType in ('',D.POType)  and @MachineId in (0,D.MachineId)
			          ) A 
					 where (@SearchString is null or
							A.DPRNo like '%' +@SearchString + '%' or
							A.DPRDate like '%' +@SearchString + '%' or
							A.POType like '%' +@SearchString + '%' or
							A.PONo like '%' +@SearchString+ '%' or
							A.RouteCardNo like '%' +@SearchString+ '%' or
							A.PartNo like '%' +@SearchString+ '%' or
							A.ItemDescription like '%' +@SearchString + '%' or
			                A.Operation like '%'+@SearchString + '%'or
							A.Qty like '%' +@SearchString + '%'or
							A.SettingTime like '%' +@SearchString + '%'or
							A.ProdTime like '%' +@SearchString + '%'or
							A.SettingHrs like '%' +@SearchString + '%'or
							A.ProdHrs like '%' +@SearchString + '%'or
							A.ContinueShift like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec

END
ELSE IF @Action='GetMinimumStkDtls'
BEGIN
                Select IT.ItemTypeName,I.PartNo,I.Description,U.UnitName,CAST(ISNULL(S.Qty,'0') as float) as AvlQty,
				CAST(isnull(I.ReOrderQty,'0') as float) as ReOrderQty
				from itemMaster I
				left join ItemTypeMaster IT on IT.ItemTypeId=I.ItemTypeId and IT.IsActive=1 
				left join UnitMaster U on U.UnitId=I.UOMId and U.IsActive=1 
				left join ItemStock S on I.itemId =S.itemId and S.isActive=1 
				WHERE I.IsActive=1 AND CAST(ISNULL(S.Qty,'0') as float) < CAST(isnull(I.ReOrderQty,'0') as float) 
END

ELSE IF @Action='GetRMWiseRMPODtls'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.RMPOId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.RMPONo  end asc,
				    case when (@SortCol =1 and  @SortDir ='desc')then A.RMPONo end desc,
				    case when (@SortCol =2 and  @SortDir ='asc')  then A.Date  end asc,
					case when (@SortCol =2 and  @SortDir ='desc')  then A.Date end desc,
					case when (@SortCol =3 and  @SortDir ='asc') then A.Supplier  end asc,
					case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.CodeNo  end asc,
				    case when (@SortCol =4 and  @SortDir ='desc')then A.CodeNo end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.Description  end asc,
				    case when (@SortCol =5 and  @SortDir ='desc')then A.Description end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.Qty  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.Qty end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.QtyKgs  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.QtyKgs end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.Rate  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.Rate end desc,
					case when (@SortCol =9 and  @SortDir ='asc') then A.TaxAmt  end asc,
				    case when (@SortCol =9 and  @SortDir ='desc')then A.TaxAmt end desc,
					case when (@SortCol =10 and  @SortDir ='asc') then A.Amount  end asc,
				    case when (@SortCol =10 and  @SortDir ='desc')then A.Amount end desc,
					case when (@SortCol =11 and  @SortDir ='asc') then A.SpecificationRemarks  end asc,
				    case when (@SortCol =11 and  @SortDir ='desc')then A.SpecificationRemarks end desc
					)as RowNum from(
							Select RM.RMPOId, RM.RMPONo,CONVERT(varchar,cast(RM.Date as date),105) as Date,C.CustomerName as Supplier, 
							R.CodeNo,R.Description,RS.Qty,RS.QtyKgs,RS.Rate,RS.TaxAmt,RS.Amount,RS.SpecificationRemarks,
							COUNT(*) over() as TotalCount from RMPOMain RM 
							INNER JOIN RMPOSub RS ON RS.RMPOId=RM.RMPOId AND RS.IsActive=1
							INNER JOIN RawMaterial R ON R.RawMaterialId=RS.RawMaterialId AND R.IsActive=1 
							INNER JOIN CustomerMaster C ON C.CustomerId=RM.SupplierId AND C.IsActive=1 
							WHERE RM.IsActive=1 and CAST(RM.Date as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
			          ) A 
					 where (@SearchString is null or
							A.RMPONo like '%' +@SearchString + '%' or
							A.Date like '%' +@SearchString + '%' or
							A.Supplier like '%' +@SearchString + '%' or
							A.CodeNo like '%' +@SearchString+ '%' or
							A.Description like '%' +@SearchString+ '%' or
							A.Qty like '%' +@SearchString+ '%' or
			                A.QtyKgs like '%'+@SearchString + '%'or
							A.Rate like '%' +@SearchString + '%'or
							A.TaxAmt like '%' +@SearchString + '%'or
							A.Amount like '%' +@SearchString + '%'or
							A.SpecificationRemarks like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec

END
ELSE IF @Action='GetItemWisePODtls'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.POId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.PONO  end asc,
				    case when (@SortCol =1 and  @SortDir ='desc')then A.PONO end desc,
				    case when (@SortCol =2 and  @SortDir ='asc')  then A.Date  end asc,
					case when (@SortCol =2 and  @SortDir ='desc')  then A.Date end desc,
					case when (@SortCol =3 and  @SortDir ='asc') then A.Supplier  end asc,
					case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.PartNo  end asc,
				    case when (@SortCol =4 and  @SortDir ='desc')then A.PartNo end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.Description  end asc,
				    case when (@SortCol =5 and  @SortDir ='desc')then A.Description end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.Qty  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.Qty end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.Rate  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.Rate end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.TaxAmt  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.TaxAmt end desc,
					case when (@SortCol =9 and  @SortDir ='asc') then A.Amount  end asc,
				    case when (@SortCol =9 and  @SortDir ='desc')then A.Amount end desc,
					case when (@SortCol =10 and  @SortDir ='asc') then A.SpecificationRemarks  end asc,
				    case when (@SortCol =10 and  @SortDir ='desc')then A.SpecificationRemarks end desc
					)as RowNum from(
								Select PM.POId,PM.PONO,CONVERT(varchar,cast(PM.Date as date),105) as Date,C.CustomerName as Supplier,
								I.PartNo,I.Description,PS.Qty,PS.Rate,PS.TaxAmt,PS.Amount,PS.SpecificationRemarks,
								COUNT(*) over() as TotalCount from PurchaseOrderMain PM
								inner join PurchaseOrderSub PS on PS.POId=PM.POId and PS.IsActive=1 
								INNER JOIN ItemMaster I ON I.ItemId=PS.ItemId AND I.IsActive=1 
								INNER JOIN CustomerMaster C ON C.CustomerId=PM.SupplierId AND C.IsActive=1 
								where PM.IsActive=1 and CAST(PM.Date as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
			          ) A 
					 where (@SearchString is null or
							A.PONO like '%' +@SearchString + '%' or
							A.Date like '%' +@SearchString + '%' or
							A.Supplier like '%' +@SearchString + '%' or
							A.PartNo like '%' +@SearchString+ '%' or
							A.Description like '%' +@SearchString+ '%' or
							A.Qty like '%' +@SearchString+ '%' or
							A.Rate like '%' +@SearchString + '%'or
							A.TaxAmt like '%' +@SearchString + '%'or
							A.Amount like '%' +@SearchString + '%'or
							A.SpecificationRemarks like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec
END
ELSE IF @Action='GetDeletedDCDtls'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.DCId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.DCNo  end asc,
				    case when (@SortCol =1 and  @SortDir ='desc')then A.DCNo end desc,
				    case when (@SortCol =2 and  @SortDir ='asc')  then A.DCDate  end asc,
					case when (@SortCol =2 and  @SortDir ='desc')  then A.DCDate end desc,
					case when (@SortCol =3 and  @SortDir ='asc') then A.VendorName  end asc,
					case when (@SortCol =3 and  @SortDir ='desc') then A.VendorName end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.GSTNo  end asc,
				    case when (@SortCol =4 and  @SortDir ='desc')then A.GSTNo end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.RequireByDate  end asc,
				    case when (@SortCol =5 and  @SortDir ='desc')then A.RequireByDate end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.POType  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.POType end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.RemovedBy  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.RemovedBy end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.RemovedOn  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.RemovedOn end desc
					)as RowNum from(
							SELECT DC.DCId,DC.DCNo,CONVERT(varchar,cast(DC.DCDate as date),105) as DCDate,
							C.CustomerName AS VendorName,CA.B_GSTNo as GSTNo,
							case when DC.RequireByDate <>'' then  CONVERT(varchar,cast(DC.RequireByDate as date),105) end as RequireByDate,
							DC.POType, E.EmpName as RemovedBy,DC.RemovedOn,COUNT(*) over() as TotalCount
							FROM DCEntryMain DC
							INNER JOIN CustomerMaster C ON C.CustomerId=DC.SupplierId AND C.IsActive=1 
							left JOIN CustAddressDtls CA on CA.CustomerId=C.CustomerId and CA.IsActive=1 
							INNER JOIN EmployeeDetails E ON E.EmpId=DC.RemovedBy AND E.IsActive=1 
							WHERE DC.IsActive=0 AND DC.Status='InActive'
			          ) A 
					 where (@SearchString is null or
							A.DCNo like '%' +@SearchString + '%' or
							A.DCDate like '%' +@SearchString + '%' or
							A.VendorName like '%' +@SearchString + '%' or
							A.GSTNo like '%' +@SearchString+ '%' or
							A.RequireByDate like '%' +@SearchString+ '%' or
							A.POType like '%' +@SearchString+ '%' or
							A.RemovedBy like '%' +@SearchString + '%'or
							A.RemovedOn like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec
END
ELSE IF @Action='GetPurchaseOrderStatusReport'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.POId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.PONo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Date	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Supplier end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.Description	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.Description end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.Qty end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.Qty end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.ReceivedQty end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.ReceivedQty end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.Status end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.Status end desc		    
                     ) as RowNum  
					 from (	
					 Select *,COUNT(*) over() as TotalCount from(						 
							Select RM.RMPOId as POId,RM.RMPONo as PONo,CONVERT(varchar,cast(RM.Date as date),105) as Date,C.CustomerName AS Supplier,
							R.CodeNo +'-'+R.Description as Description,RS.Qty,cast(RS.Qty as float)-cast(isnull(RS.GRNBalQty,'0') as float) as ReceivedQty,
							case when cast(isnull(RS.GrnBalQty,'0') as float) > 0 then'Not Closed' else 'Closed' end  as Status
							from RMPOMain RM
							INNER JOIN RMPOSub RS ON RS.RMPOId =RM.RMPOId and RS.IsActive=1 
							INNER JOIN CustomerMaster C ON C.CustomerId=RM.SupplierId AND C.IsActive=1
							INNER JOIN RawMaterial R ON R.RawMaterialId=RS.RawMaterialId and R.IsActive=1 
							where RM.IsActive=1 and @SupplierId in (0,RM.SupplierId) and CAST(RM.Date as date) between cast(@FromDate as date) and CAST(@ToDate as date)
							union all 
							Select PM.POId,PM.PONO,CONVERT(varchar,cast(PM.Date as date),105) as Date,C.CustomerName as Supplier,
							I.PartNo+' - '+I.Description as Description,PS.Qty,cast(PS.Qty as float)-cast(isnull(PS.GRNBalQty,'0') as float) as ReceivedQty,
							case when cast(isnull(PS.GrnBalQty,'0') as float) > 0 then'Not Closed' else 'Closed' end  as Status
							from PurchaseOrderMain PM
							inner join PurchaseOrderSub PS on PS.POId=PM.POId and PS.IsActive=1 
							INNER JOIN CustomerMaster C ON C.CustomerId=PM.SupplierId AND C.IsActive=1
							INNER JOIN ItemMaster I on I.ItemId=PS.ItemId and I.IsActive=1 
							where PM.IsActive=1 and @SupplierId in (0,PM.SupplierId) and CAST(PM.Date as date) between cast(@FromDate as date) and CAST(@ToDate as date)				
						 ) A)A where (@SearchString is null or A.PONo like '%' +@SearchString+ '%' or
									A.Date like '%' +@SearchString+ '%' or A.Supplier like '%' +@SearchString+ '%' or
									A.Description like '%' + @SearchString+ '%' or A.Qty like '%' +@SearchString+ '%'or
									A.ReceivedQty like '%' + @SearchString+ '%' or A.Status like '%' +@SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetDeliveryScheduleDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DCId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.DCNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.DCNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.DCDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DCDate	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Supplier end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.POType end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.ItemDescription end desc,	
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.RMDescription end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.RMDescription end desc,			
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.Operation end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.Operation end desc,	
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.DCQty end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.DCQty end desc,	
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.DeliverySchedule end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.DeliverySchedule end desc,	
							 case when (@SortCol =12 and  @SortDir ='asc')  then A.InwardDCDate end asc,
							 case when (@SortCol =12 and  @SortDir ='desc') then A.InwardDCDate end desc,	
							 case when (@SortCol =13 and  @SortDir ='asc')  then A.InwardDCQty end asc,
							 case when (@SortCol =13 and  @SortDir ='desc') then A.InwardDCQty end desc,   
							 case when (@SortCol =14 and  @SortDir ='asc')  then A.diffDays end asc,
							 case when (@SortCol =14 and  @SortDir ='desc') then A.diffDays end desc   
                     ) as RowNum  
					 from (	
								Select DC.DCId,DC.DCNo,DC.DCDate,C.CustomerName as Supplier,DC.POType,ISNULL(PM.PrePONo,JM.PONo) as PONo,
								isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
								R.CodeNo +' - ' + R.Description as RMDescription,
								'P'+cast(DS.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,DS.Qty as DCQty,DC.DeliverySchedule,
								IM.InwardDCDate,IDS.InwardDCQty,COUNT(*) over() as TotalCount,
								case when DC.DeliverySchedule Is Not Null and DC.DeliverySchedule <>'' AND IM.InwardDcDate Is Not Null Then DATEDIFF(day,cast(DC.DeliverySchedule as date), cast(IM.InwardDcDate as date)) else '' end as 'diffDays'
								from
								DCEntryMain DC
								inner join DCEntrySub DS on  DS.DCId=DC.DCId and DS.IsActive=1 
								left join InwardDCSub IDS on IDS.DCId=DS.DCId and IDS.RouteEntryId=DS.RouteEntryId and IDS.RoutLineNo=DS.RoutLineNo and IDS.IsActive=1 
								left join InwardDCMain IM on IM.InwardDCId=IDS.InwardId and IM.IsActive=1 
								left join PrePOMain PM on DC.POType='CustomerPO' and  PM.PrePOId =DS.PrePOId and PM.isActive=1
								left join ItemMaster I on DC.POType='CustomerPO' and I.ItemId=DS.ItemId and I.IsActive=1
								left join JobOrderPOMain JM on   DC.POType='JobOrderPO' and  JM.JobOrderPOId =DS.PrePOId and JM.isActive=1
								left join JobOrderPOSub JS on DC.POType='JobOrderPO' and JS.JobOrderPOId=DS.PrePOId and JS.JobOrderPOSubId=DS.ItemId and JS.IsActive=1	
								left join RawMaterial R on DC.POType='CustomerPO' and  R.RawMaterialId =DS.RawMaterialId and R.IsActive=1 
								inner join OperationMaster O on O.OperationId=DS.OperationId and O.IsActive=1 	
								inner join CustomerMaster C on C.CustomerId=DC.SupplierId and C.IsActive=1 
								where DC.IsActive=1 and @SupplierId in (0,DC.SupplierId) and CAST(DC.DCDate as date) between CAST(@FromDate as date) and cast(@ToDate as date)
								and @DCId in (0,DC.DCId)
					    )A where (@SearchString is null or A.DCNo like '%' +@SearchString+ '%' or
									A.DCDate like '%' +@SearchString+ '%' or A.Supplier like '%' +@SearchString+ '%' or
									A.POType like '%' + @SearchString+ '%' or A.PONo like '%' +@SearchString+ '%'or
									A.PartNo like '%' + @SearchString+ '%' or A.ItemDescription like '%' +@SearchString+ '%'or
									A.RMDescription like '%' + @SearchString+ '%' or A.Operation like '%' +@SearchString+ '%'or
									A.DCQty like '%' + @SearchString+ '%' or A.DeliverySchedule like '%' +@SearchString+ '%'or
									A.InwardDCQty like '%' + @SearchString+ '%' or A.InwardDCDate like '%' +@SearchString+ '%'or
									A.diffDays like '%' + @SearchString+ '%'
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetAllDCNos'
BEGIN
   SELECT DC.DCId,DC.DCNo FROM DCEntryMain DC
   where DC.IsActive=1 and DC.SupplierId=@SupplierId;
END

ELSE IF @Action='GetPODetailedReport'
BEGIN
--RM Planning
	 Select R.CodeNo,R.Description,R.Dimension,RP.Text1,RP.Text2,RP.Text3, RP.Value1, RP.Value2 , RP.Value3,RP.Weight from RMPlanning RP
	 inner join RawMaterial R on R.RawMaterialId =RP.RawMaterialId and R.IsActive=1 
	 where RP.IsActive=1  and @POType='CustomerPO' and RP.PrePOId=@PrePOId and RP.ItemId=@ItemId
--Process Wise Production
    Select O.OperationCode+' - ' + O.OperationName as Operation,ISNULL(PS.Qty,JS.Qty) as POQty ,R.ProcessQty,ISNULL(PO.TotalAccQty,'0') as OKQty,ISNULL(PO.RejQty,'0') as RejQty,
	ISNULL(PO.ReworkQty,'0') as ReworkQty from RouteCardEntry R
	left join PrePOSub PS on R.POType='CustomerPO' and PS.PrePOId=R.PrePoId and PS.ItemId=R.ItemId and PS.IsActive=1 
	left join JobOrderPOSub JS on R.POType='JobOrderPO' and JS.JobOrderPOId=R.PrePoId and JS.JobOrderPOSubId=R.ItemId and JS.IsActive=1 
	left join POProcessQtyDetails PO on PO.RouteEntryId=R.RouteEntryId and PO.RoutLineNo=R.RoutLineNo and PO.IsActive=1 
	inner join OperationMaster O on O.OperationId=R.OperationId and O.IsActive=1
	where R.IsActive=1 and R.POType=@POType and R.PrePOId=@PrePOId and R.ItemId=@ItemId  
	order by R.RoutLineNo asc;
	
--DC Dtls
	Select DM.DCId,DM.DCNo,DM.DCDate,C.CustomerName as Vendor,'P'+cast(DS.RoutLineNo as varchar) +' - '+O.OperationName as Process,
	DS.Qty,cast(DS.Qty as float)-cast(isnull(DS.InwardBalQty,'0') as float) as InwardDCQty,
	case when cast(isnull(DS.InwardBalQty,'0') as float) > 0 then'Not Closed' else 'Closed' end  as Status
	from DCEntrySub DS
	inner join OperationMaster O on O.OperationId=DS.OperationId and O.IsActive=1 
	inner join DCEntryMain DM on DM.DCId=DS.DCId and DM.IsActive=1 
	inner join CustomerMaster C on C.CustomerId=DM.SupplierId and C.IsActive=1 
	where DS.IsActive=1 and DM.POType=@POType and DS.PrePOId=@PrePOId and DS.ItemId=@ItemId;
--Prod Dtls
	Select D.DPRNo,D.DPRDate,	M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
	'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,
	D.DPRKey,
	D.StartTime +' To ' + D.EndTime as Setting_ProdTime,E.EmpName as Setting_ProdEmp,D.Qty,
	case when D.ContinueShift='false' then 'Yes' else '' end as ContinueShift
	from DPREntry D
	inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 
	inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
	inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
	where D.IsActive=1 and D.POType=@POType and D.PrePoId=@PrePOId and D.ItemId=@ItemId order by D.DPRId Desc
--Rejection Details
	Select * from (
			Select J.JWDate as Date, J.RejQty,cast(J.RoutLineNo as varchar)+' - '  + O.OperationName as Process,RJ.Rejection as Reason from JobWorkInspection J
			inner join OperationMaster O on O.OperationId=J.OperationId and O.IsActive=1 
			left join RejectionReason RJ on RJ.RejectionReasonId=J.RejReasonId and RJ.IsActive=1 
			where J.IsActive=1  and  cast(isnull(J.RejQty,'0') as float)>0  and J.POType=@POType and J.PrePoId=@PrePOId and J.ItemId=@ItemId
			union all
			Select J.QCDate as Date, J.RejQty,cast(J.RoutLineNo as varchar)+' - '  + O.OperationName as Process,RJ.Rejection as Reason from IntermediateQC J
			inner join OperationMaster O on O.OperationId=J.OperationId and O.IsActive=1 
			left join RejectionReason RJ on RJ.RejectionReasonId=J.RejReasonId and RJ.IsActive=1 
			where J.IsActive=1  and  cast(isnull(J.RejQty,'0') as float)>0   and  cast(isnull(J.RejQty,'0') as float)>0  and J.POType=@POType and J.PrePoId=@PrePOId and J.ItemId=@ItemId
			union all 
			Select J.Date, J.RejQty,cast(J.RouteLineNo as varchar)+' - '  + O.OperationName as Process,'' as Reason   from ManualProductionEntry J
			inner join RouteCardEntry RC on RC.POType=J.POType and RC.RouteEntryId=J.RouteEntryId and RC.RoutLineNo=J.RouteLineNo and RC.IsActive=1 
			inner join OperationMaster O on O.OperationId=RC.OperationId and O.IsActive=1 								
			where J.IsActive=1  and  cast(isnull(J.RejQty,'0') as float)>0   and  cast(isnull(J.RejQty,'0') as float)>0  and J.POType=@POType and J.PrePoId=@PrePOId and J.ItemId=@ItemId
		) A order by cast(A.Date as date) desc
 
END
ELSE IF @Action='GetCustomerPOStatusReport'
BEGIN
    Select PM.PrePOId,PM.PrePONo,PM.InternalPODate,C.CustomerName,PM.Status from PrePOMain PM
	inner join CustomerMaster C on C.CustomerId=PM.CustId and C.IsActive=1 
	where PM.IsActive=1 order by PM.PrePOId desc
END
ELSE IF @Action='GetCustomerPrePOSubDtls'
BEGIN
 Select A.PartNo,A.Description,A.UnitName,A.POQty,A.ProdQty,A.Status from (
		SELECT PS.PrePOID,PS.ItemId, I.PartNo,I.Description,U.UnitName,PS.Qty AS POQty,PS.Status,
		RC.RoutLineNo,(MAX(RC.RoutLineNo) OVER (PARTITION BY RC.RouteEntryId)) AS MRoutLineNo,
		isnull(PO.TotalAccQty,0) as ProdQty
		 FROM PrePOSub PS
		left join RouteCardEntry RC on RC.POType='CustomerPO' and  RC.PrePOId=PS.PrePOId and RC.ItemId=PS.ItemId and RC.IsActive=1 
		left join POProcessQtyDetails PO on PO.POType='CustomerPO' and  PO.RouteEntryId=RC.RouteEntryId and PO.RoutLineNo=RC.RoutLineNo and PO.IsActive=1 
		INNER JOIN ItemMaster I ON I.ItemId=PS.ItemId AND I.IsActive=1 
		LEFT JOIN UnitMaster U on U.UnitId=I.UOMId AND U.IsActive=1 
		WHERE PS.IsActive=1 AND PS.PrePOId=@PrePOId
	)A where A.RoutLineNo is null or A.RoutLineNo=A.MRoutLineNo
END
ELSE IF @Action='GetIMQCRejDtls'
BEGIN
      SET @FirstRec=@DisplayStart;
      SET @LastRec=@DisplayStart+@DisplayLength;
					
		select * from (
		     select A.*,COUNT(A.QCId) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.QCId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.QCNo  end asc,
				    case when (@SortCol =1 and  @SortDir ='desc')then A.QCNo end desc,
					case when (@SortCol =2 and  @SortDir ='asc') then A.QCDate  end asc,
					case when (@SortCol =2 and  @SortDir ='desc') then A.QCDate end desc,
					case when (@SortCol =3 and  @SortDir ='asc')  then A.EmpName  end asc,
				    case when (@SortCol =3 and  @SortDir ='desc') then A.EmpName  end desc, 
				    case when (@SortCol =4 and  @SortDir ='asc')  then A.POType  end asc,
					case when (@SortCol =4 and  @SortDir ='desc')  then A.POType end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.PONo  end asc,
					case when (@SortCol =5 and  @SortDir ='desc') then A.PONo end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.PartNo  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.PartNo end desc,
					case when (@SortCol =7 and  @SortDir ='asc') then A.ItemDescription  end asc,
				    case when (@SortCol =7 and  @SortDir ='desc')then A.ItemDescription end desc,
					case when (@SortCol =8 and  @SortDir ='asc') then A.Operation  end asc,
				    case when (@SortCol =8 and  @SortDir ='desc')then A.Operation end desc,
					case when (@SortCol =9 and  @SortDir ='asc') then A.MachineCode_Name  end asc,
				    case when (@SortCol =9 and  @SortDir ='desc')then A.MachineCode_Name end desc,
					case when (@SortCol =10 and  @SortDir ='asc') then A.RejQty  end asc,
				    case when (@SortCol =10 and  @SortDir ='desc')then A.RejQty end desc,
					case when (@SortCol =11 and  @SortDir ='asc') then A.Rejection  end asc,
				    case when (@SortCol =11 and  @SortDir ='desc')then A.Rejection end desc
					)as RowNum from(
							Select IQ.QCId, IQ.QCNo,IQ.QCDate,E.EmpName, IQ.POType,
							ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							'P'+cast(IQ.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,
							M.MachineCode +' - ' + M.MachineName as MachineCode_Name,IQ.RejQty , RR.Rejection,
							Count(IQ.QCId) over() as TotalCount							from IntermediateQC IQ
							inner join DPREntry D on D.DPRID=IQ.DPRId and D.IsActive=1
							left join PrePOMain PM on IQ.POType='CustomerPO' and  PM.PrePOId =IQ.PrePOId and PM.isActive=1
							left join JobOrderPOMain JM on   IQ.POType='JobOrderPO' and  JM.JobOrderPOId =IQ.PrePOId and JM.isActive=1
							left join ItemMaster I on IQ.POType='CustomerPO' and I.ItemId=IQ.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on IQ.POType='JobOrderPO' and JS.JobOrderPOId=IQ.PrePOId and JS.JobOrderPOSubId=IQ.ItemId and JS.IsActive=1
							inner join OperationMaster O on O.OperationId=IQ.OperationId and O.IsActive=1 
							inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 
							left join RejectionReason RR on RR.RejectionReasonId=IQ.RejReasonId and RR.IsActive=1
							inner join EmployeeDetails E on E.EmpId=D.ProdEmpId and E.IsActive=1 
							where IQ.IsActive=1 and cast(isnull(IQ.RejQty,'0') as float)>0 and cast(IQ.QCDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
							 and @POType in ('',D.POType)  and @EmployeeId in (0,D.ProdEmpId)
			          ) A 
					 where (@SearchString is null or
							A.QCNo like '%' +@SearchString + '%' or
							A.QCDate like '%' +@SearchString + '%' or
							A.EmpName like '%' +@SearchString + '%' or
							A.POType like '%' +@SearchString+ '%' or
							A.PONo like '%' +@SearchString+ '%' or
							A.PartNo like '%' +@SearchString+ '%' or
							A.ItemDescription like '%' +@SearchString + '%' or
			                A.Operation like '%'+@SearchString + '%'or
							A.MachineCode_Name like '%' +@SearchString + '%'or
							A.RejQty like '%' +@SearchString + '%'or
							A.Rejection like '%' +@SearchString + '%'
						  ))B where  RowNum > @FirstRec and RowNum <= @LastRec

END

--18-12-2022
ELSE IF @Action='GetNewlyAddedPODtls'
BEGIN
   SELECT PM.PrePONo,C.CustomerName, I.PartNo, I.Description,PS.Qty FROM PrePOMain PM
   inner join PrePOSub PS on PS.PrePOId=PM.PrePOId and PS.Isactive=1 
   inner join ItemMaster I on I.ItemId =PS.ItemId and I.Isactive=1 
   INNER JOIN CustomerMaster C on C.CustomerId=PM.CustId and C.IsActive=1
   where PM.IsActive=1 and PM.InternalPODate=CAST(GETDATE() as date)
   order by PM.PrePOId desc
END
ELSE IF @Action='GetNotificationDtls'
BEGIN
   SELECT NotificationId,Details FROM NotificationDtls 
   where Status='Open' and IsActive=1 order by NotificationId desc;
END
ELSE IF @Action='CloseNotification'
BEGIN
   UPDATE NotificationDtls SET Status='Closed' where NotificationId=@NotificationId;

    SELECT NotificationId,Details FROM NotificationDtls 
   where Status='Open' and IsActive=1 order by NotificationId desc;
END
ELSE IF @Action='GetVendorDCOutSourcingDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DCId end desc,
							 case when (@SortCol =1 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.POType end desc,	
			                 case when (@SortCol =2 and  @SortDir ='asc')  then A.DCNo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DCNo	end desc ,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.DCDate	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.DCDate	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.Vendor end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.Vendor end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.ItemDescription end desc,			
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.Operation end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.Operation end desc,	
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.Qty end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.Qty end desc
                     ) as RowNum  
					 from (	
							Select DM.DCId, DM.POType,DM.DCNo,CONVERT(varchar,cast(DM.DCDate as date),105) as DCDate,
							C.CustomerName as Vendor,ISNULL(PM.PrePONo,JM.PONo) as PONo,
							isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							'P'+cast(DS.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,DS.Qty,
							COUNT(*) over() as TotalCount
							 from DCEntryMain DM
							inner join DCEntrySub DS on DS.DCId=DM.DCId and DS.IsActive=1 
							left join PrePOMain PM on DM.POType='CustomerPO' and  PM.PrePOId =DS.PrePOId and PM.isActive=1
							left join ItemMaster I on DM.POType='CustomerPO' and I.ItemId=DS.ItemId and I.IsActive=1
							left join JobOrderPOMain JM on  DM.POType='JobOrderPO' and  JM.JobOrderPOId =DS.PrePOId and JM.isActive=1
							left join JobOrderPOSub JS on DM.POType='JobOrderPO' and JS.JobOrderPOId=DS.PrePOId and JS.JobOrderPOSubId=DS.ItemId and JS.IsActive=1	
							inner join OperationMaster O on O.OperationId=DS.OperationId and O.IsActive=1 	
							inner join CustomerMaster C on c.CustomerId=DM.SupplierId and C.IsActive=1 
							where DM.IsActive=1
							 and @SupplierId in (0,DM.SupplierId) and CAST(DM.DCDate as date) between CAST(@FromDate as date) and cast(@ToDate as date)
								and @POType in ('',DM.POType) and @PrePOId in (0,DS.PrePOId) and @ItemId in (0,DS.ItemId)
					    )A where (@SearchString is null or A.DCNo like '%' +@SearchString+ '%' or
									A.DCDate like '%' +@SearchString+ '%' or A.Vendor like '%' +@SearchString+ '%' or
									A.POType like '%' + @SearchString+ '%' or A.PONo like '%' +@SearchString+ '%'or
									A.PartNo like '%' + @SearchString+ '%' or A.ItemDescription like '%' +@SearchString+ '%'or
									 A.Operation like '%' +@SearchString+ '%'or	A.Qty like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetVendorPendingDCDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DCId end desc,
							 case when (@SortCol =1 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.POType end desc,	
			                 case when (@SortCol =2 and  @SortDir ='asc')  then A.DCNo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DCNo	end desc ,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.DCDate	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.DCDate	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.Vendor end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.Vendor end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.ItemDescription end desc,			
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.Operation end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.Operation end desc,	
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.Qty end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.Qty end desc,
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.RequireByDate end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.RequireByDate end desc,
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.DespatchThrough end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.DespatchThrough end desc
                     ) as RowNum  
					 from (	
							Select DM.DCId, DM.POType,DM.DCNo,CONVERT(varchar,cast(DM.DCDate as date),105) as DCDate,
							C.CustomerName as Vendor,ISNULL(PM.PrePONo,JM.PONo) as PONo,
							isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							'P'+cast(DS.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,DS.Qty,
							DM.RequireByDate,DM.DespatchThrough,
							COUNT(*) over() as TotalCount
							 from DCEntryMain DM
							inner join DCEntrySub DS on DS.DCId=DM.DCId and DS.IsActive=1 
							left join PrePOMain PM on DM.POType='CustomerPO' and  PM.PrePOId =DS.PrePOId and PM.isActive=1
							left join ItemMaster I on DM.POType='CustomerPO' and I.ItemId=DS.ItemId and I.IsActive=1
							left join JobOrderPOMain JM on  DM.POType='JobOrderPO' and  JM.JobOrderPOId =DS.PrePOId and JM.isActive=1
							left join JobOrderPOSub JS on DM.POType='JobOrderPO' and JS.JobOrderPOId=DS.PrePOId and JS.JobOrderPOSubId=DS.ItemId and JS.IsActive=1	
							inner join OperationMaster O on O.OperationId=DS.OperationId and O.IsActive=1 	
							inner join CustomerMaster C on c.CustomerId=DM.SupplierId and C.IsActive=1 
							where DM.IsActive=1 and CAST(isnull(DS.InwardBalQty,'0') as float) >0
							 and @SupplierId in (0,DM.SupplierId) and @POType in ('', DM.POType)
					    )A where (@SearchString is null or A.DCNo like '%' +@SearchString+ '%' or
									A.DCDate like '%' +@SearchString+ '%' or A.Vendor like '%' +@SearchString+ '%' or
									A.POType like '%' + @SearchString+ '%' or A.PONo like '%' +@SearchString+ '%'or
									A.PartNo like '%' + @SearchString+ '%' or A.ItemDescription like '%' +@SearchString+ '%'or
									 A.Operation like '%' +@SearchString+ '%'or	A.Qty like '%' + @SearchString+ '%' or
									 A.RequireByDate like '%' +@SearchString+ '%'or	A.DespatchThrough like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetRMMidStockDtls'
BEGIN
        Select RM.RawMaterialId,RM.OperationId,RM.Text1,RM.Text2,RM.Text3,RM.Value1,RM.Value2,RM.Value3,
		 R.CodeNo,R.Description,RM.Value1 + case when RM.Value2 is not null and RM.Value2<> '' then '*' +RM.Value2 else '' end +'*'+RM.Value3 as Dimension,
		O.OperationName,RM.Qty from RMMidStock RM
		inner join RawMaterial R on R.RawMaterialId=RM.RawMaterialId and R.IsActive=1 
		inner join OperationMaster O on O.OperationId=RM.OperationId and O.IsActive=1 
		where RM.IsActive=1 
END
ELSE IF @Action='GetAllDCStatusDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DCId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.DCNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.DCNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.DCDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DCDate	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Vendor end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Vendor end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.POType end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.ItemDescription end desc,	
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.Qty end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.Qty end desc,
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.InwardQty end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.InwardQty end desc,
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.Status end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.Status end desc
                     ) as RowNum  
					 from (	
					 Select A.*,COUNT(*) over() as TotalCount from (
							Select 'VendorDC' as Type, DC.DCId,DC.DCNo,DC.DCDate,C.CustomerName as Vendor,
							DC.POType,ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							DS.Qty, cast(ISNULL(DS.Qty,'0') as decimal(18,2))- cast(ISNULL(DS.InwardBalQty,'0') as decimal(18,2)) as InwardQty,
							case when  cast(ISNULL(DS.InwardBalQty,'0') as float) >0 then 'Not Closed' else 'Closed' end as Status
							from DCEntryMain DC
							inner join DCEntrySub DS on DS.DCId=DC.DCId and DS.IsActive=1 
							inner join CustomerMaster C on C.CustomerId =DC.SupplierId and C.IsActive=1 
							left join PrePOMain PM on DC.POType='CustomerPO' and  PM.PrePOId =DS.PrePOId and PM.isActive=1
							left join JobOrderPOMain JM on   DC.POType='JobOrderPO' and  JM.JobOrderPOId =DS.PrePOId and JM.isActive=1
							left join ItemMaster I on DC.POType='CustomerPO' and I.ItemId=DS.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on DC.POType='JobOrderPO' and JS.JobOrderPOId=DS.PrePOId and JS.JobOrderPOSubId=DS.ItemId and JS.IsActive=1							
							where DC.IsActive=1 and @SupplierId in  (0,DC.SupplierId) and CAST(DC.DCDate as date) between cast(@FromDate as date) and cast(@ToDate as date)
							union all
							Select 'MaterialOutDC' as Type, MM.MaterialOutDCId as DCID, MM.MaterialOutDCNo as DCNo,MM.Date as DCDate,C.CustomerName as Vendor,
							'' as POType,'' as PONo,'' as PartNo,MS.ItemDescription,
							MS.Qty, cast(ISNULL(MS.Qty,'0') as decimal(18,2))- cast(ISNULL(MS.InwardBalQty,'0') as decimal(18,2)) as InwardQty,
							case when  cast(ISNULL(MS.InwardBalQty,'0') as float) >0 then 'Not Closed' else 'Closed' end as Status
							 from MaterialOutDCMain MM
							inner join MaterialOutDCSub MS on MS.MaterialOutDCId=MM.MaterialOutDCId and MS.IsActive=1 
							inner join CustomerMaster C on C.CustomerId =MM.CustomerId and C.IsActive=1 
							where MM.IsActive=1  and @SupplierId in  (0,MM.CustomerId) and CAST(MM.Date as date) between cast(@FromDate as date) and cast(@ToDate as date)
						)A)A where (@SearchString is null or A.DCNo like '%' +@SearchString+ '%' or
									A.DCDate like '%' +@SearchString+ '%' or A.Vendor like '%' +@SearchString+ '%' or
									A.POType like '%' + @SearchString+ '%' or A.PONo like '%' +@SearchString+ '%'or
									A.PartNo like '%' + @SearchString+ '%' or A.ItemDescription like '%' +@SearchString+ '%'or
									A.Qty like '%' + @SearchString+ '%' or
									 A.InwardQty like '%' +@SearchString+ '%'or	A.Status like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetProcessWiseProdDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.PrePOId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.PrePONo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.PrePONo	end desc,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.PartNo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.PartNo	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Description end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Description end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.POQty	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.POQty end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.Processqty end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.Processqty end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.ProdQty end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.ProdQty end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.Reworkqty end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.Reworkqty end desc,	
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.Rejqty end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.Rejqty end desc,
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.Status end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.Status end desc
                     ) as RowNum  
					 from (	
					 Select A.*,COUNT(*) over() as TotalCount from (
							Select * from (
										Select 'CustomerPO' as POType,A.PrePOId,A.ItemId,A.PrePONo,A.PartNo,A.Description,A.POQty,A.Processqty,A.ProdQty,
										A.Reworkqty,A.Rejqty,A.Status from (
										Select  PS.PrePOId,PS.ItemId, PM.PrePONo,I.PartNo,I.Description,PS.Qty as POQty,ISNULL(RC.ProcessQty,'0') as Processqty,
										isnull(PO.TotalAccQty,0) as ProdQty,isnull(PO.ReworkQty,0) as ReworkQty,
										isnull((SUM(cast(PO.RejQty as float)) OVER (PARTITION BY PO.RouteEntryId)),0) AS RejQty,PS.Status,
										RC.RoutLineNo,(MAX(RC.RoutLineNo) OVER (PARTITION BY RC.RouteEntryId)) AS MRoutLineNo
										from PrePOSub PS
										inner join PrePOMain PM on PM.PrePOId =PS.PRePOId and PM.IsActive=1 
										inner join ItemMaster I on I.ItemId =PS.ItemId and I.IsActive=1 
										left join RouteCardEntry RC on RC.POType='CustomerPO' and  RC.PrePOId =PS.PrePOId and RC.ItemId=PS.ItemId and RC.IsActive=1 
										left join POProcessQtyDetails PO on PO.POType='CustomerPO' and PO.RouteEntryId=RC.RouteEntryId and PO.RoutLineNo=RC.RoutLineNo and PO.IsActive=1 
										where PS.IsActive=1 and @POType in ('','CustomerPO') and @PrePOId in (0,PS.PrePOId) and @ItemId in (0,PS.ItemId)
										)A where MRoutLineNo is null or A.RoutLineNo is null  or A.RoutLineNo=A.MRoutLineNo
									
										union all

										Select 'JobOrderPO' as POType,A.PrePOId,A.ItemId,A.PrePONo,A.PartNo,A.Description,A.POQty,A.Processqty,
										A.ProdQty, A.Reworkqty,A.Rejqty,A.Status from (
										Select JS.JobOrderPOId as PrePOId,JS.JobOrderPOSubId as ItemId, JM.PONo as PrePONo,JS.PartNo,JS.ItemName as Description,JS.Qty as POQty,ISNULL(RC.ProcessQty,'0') as Processqty,
										isnull(PO.TotalAccQty,0) as ProdQty,isnull(PO.ReworkQty,0) as ReworkQty,
										isnull((SUM(cast(PO.RejQty as float)) OVER (PARTITION BY PO.RouteEntryId)),0) AS RejQty,
										RC.RoutLineNo as RoutLineNo,(MAX(RC.RoutLineNo) OVER (PARTITION BY RC.RouteEntryId)) AS MRoutLineNo,JS.Status
										from JobOrderPOSub JS
										inner join JobOrderPOMain JM on JS.JobOrderPOId =JS.JobOrderPOId and JM.IsActive=1 
										left join RouteCardEntry RC on RC.POType='JobOrderPO' and  RC.PrePOId =JS.JobOrderPOId and RC.ItemId=JS.JobOrderPOSubId and RC.IsActive=1 
										left join POProcessQtyDetails PO on PO.POType='JobOrderPO' and PO.RouteEntryId=RC.RouteEntryId and PO.RoutLineNo=RC.RoutLineNo and PO.IsActive=1 
										where JS.IsActive=1 and   @POType in ('','JobOrderPO') and @PrePOId in (0,JS.JobOrderPOId) and @ItemId in (0,JS.JobOrderPOSubId)
										)A where MRoutLineNo is null or  A.RoutLineNo is null or A.RoutLineNo=A.MRoutLineNo)A 
						   )A)A where (@SearchString is null or A.PrePONo like '%' +@SearchString+ '%' or
									A.PartNo like '%' +@SearchString+ '%' or A.Description like '%' +@SearchString+ '%' or
									A.POQty like '%' + @SearchString+ '%' or A.Processqty like '%' +@SearchString+ '%'or
									A.ProdQty like '%' + @SearchString+ '%' or A.ReworkQty like '%' +@SearchString+ '%'or
									A.RejQty like '%' + @SearchString+ '%' or	A.Status like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetFirstPieceInsDtlsByStatus'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.FirstPieceInspId end desc,
							 case when (@SortCol =1 and  @SortDir ='asc')  then A.DPRNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.DPRNo end desc,	
			                 case when (@SortCol =2 and  @SortDir ='asc')  then A.DPRDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DPRDate	end desc ,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.POType	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.ItemDescription end desc,			
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.QCDate end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.QCDate end desc,	
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.QCTime end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.QCTime end desc,
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.SettingTime end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.SettingTime end desc,
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.QCBy end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.QCBy end desc
                     ) as RowNum  
					 from (	
							Select F.FirstPieceInspId,D.DPRNo,D.DPRDate,D.POType,
							ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							F.QCDate,F.QCFrom +' To '+ F.QCTo as QCTime,D.StartTime +' To ' + D.EndTime as SettingTime,
							E.EmpName as QCBy,COUNT(*) over() as TotalCount 
							from FirstPieceInspectionMain F
							inner join DPREntry D on D.DPRId=F.DPRId and D.IsActive=1 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1	
							inner join EmployeeDetails E on E.EmpId=F.PreparedBy and E.IsActive=1 							
							where F.IsActive=1  and F.QCStatus=@Status and  @POType in ('',D.POType) and @PrePOId in (0,D.PrePoId) and @ItemId in (0,D.ItemId)
							and CAST(F.QCDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
					    )A where (@SearchString is null or A.DPRNo like '%' +@SearchString+ '%' or
									A.DPRDate like '%' +@SearchString+ '%' or A.POType like '%' +@SearchString+ '%' or
									A.PONo like '%' + @SearchString+ '%' or 	A.PartNo like '%' + @SearchString+ '%' or 
									A.ItemDescription like '%' + @SearchString+ '%' or 
									A.QCDate like '%' + @SearchString+ '%' or A.QCTime like '%' +@SearchString+ '%'or
									A.SettingTime like '%' +@SearchString+ '%'or	A.QCBy like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetFinalInsDtlsByStatus'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.FinalInspectionId end desc,
							 case when (@SortCol =1 and  @SortDir ='asc')  then A.InspectionDate	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.InspectionDate end desc,	
			                 case when (@SortCol =2 and  @SortDir ='asc')  then A.InspectionTime	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.InspectionTime	end desc ,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.POType	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.ItemDescription end desc,			
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.QCBy end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.QCBy end desc
                     ) as RowNum  
					 from (	
							Select F.FinalInspectionId,F.POType,
							ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							F.InspectionDate, F.InspectFrom +' To '+ F.InspectTo as InspectionTime,
							E.EmpName as QCBy,F.Attachments,COUNT(*) over() as TotalCount
							from FinalInspectionMain F
							left join PrePOMain PM on F.POType='CustomerPO' and  PM.PrePOId =F.PrePOId and PM.isActive=1
							left join PrePOSub PS on F.POType='CustomerPO' and  PS.PrePOId =F.PrePOId  and PS.ItemId=F.ItemId and PS.isActive=1
							left join JobOrderPOMain JM on F.POType='JobOrderPO' and  JM.JobOrderPOId =F.PrePOId and JM.isActive=1
							left join ItemMaster I on F.POType='CustomerPO' and I.ItemId=F.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on F.POType='JobOrderPO' and JS.JobOrderPOId=F.PrePOId and JS.JobOrderPOSubId=F.ItemId and JS.IsActive=1	
							inner join EmployeeDetails E on E.EmpId=F.PreparedBy and E.IsActive=1 							
							where F.IsActive=1    and F.QCStatus=@Status and  @POType in ('',F.POType) and @PrePOId in (0,F.PrePoId) and @ItemId in (0,F.ItemId)
							and CAST(F.InspectionDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
					    )A where (@SearchString is null  or A.POType like '%' +@SearchString+ '%' or
									A.PONo like '%' + @SearchString+ '%' or 	A.PartNo like '%' + @SearchString+ '%' or 
									A.ItemDescription like '%' + @SearchString+ '%' or 
									A.InspectionDate like '%' + @SearchString+ '%' or A.InspectionTime like '%' +@SearchString+ '%'or
									A.QCBy like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetEndBitStockDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.InwardId end desc,
							 case when (@SortCol =1 and  @SortDir ='asc')  then A.InwardDCNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.InwardDCNo end desc,	
			                 case when (@SortCol =2 and  @SortDir ='asc')  then A.InwardDCDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.InwardDCDate	end desc ,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.CodeNo	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.CodeNo	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.Description end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.Description end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.Dimension end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.Dimension end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.Qty end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.Qty end desc
                     ) as RowNum  
					 from (	
							Select I.InwardId,IM.InwardDCNo,IM.InwardDCDate,R.CodeNo,R.Description,
							I.Text1 +'-' + I.Value1 + case when I.Text2 <>'' and  I.Text2 is not  null then ' * ' + I.Text2+ '-'+I.Value2 +' * ' else ' * ' end +I.Text3 +'-' +I.Value3 as Dimension,
							I.Qty,COUNT(*) over() as TotalCount 
							from InwardEndBitStk I
							inner join InwardDCMain IM on IM.InwardDCId=I.InwardId and IM.IsActive=1 
							inner join RawMaterial R on R.RawMaterialId=I.RawMaterialId and R.IsActive=1 
							inner join OperationMaster O on O.OperationId=I.OperationId and O.IsActive=1 
							where I.IsActive=1 
					    )A where (@SearchString is null  or A.InwardDCNo like '%' +@SearchString+ '%' or
									A.InwardDCDate like '%' + @SearchString+ '%' or 	A.CodeNo like '%' + @SearchString+ '%' or 
									A.Description like '%' + @SearchString+ '%' or 
									A.Dimension like '%' + @SearchString+ '%' or A.Qty like '%' +@SearchString+ '%'
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetPOProcessQtyDetails'
BEGIN
        Select O.OperationCode+' - ' + O.OperationName as Operation,ISNULL(PS.Qty,JS.Qty) as POQty ,R.ProcessQty,ISNULL(PO.TotalAccQty,'0') as OKQty,ISNULL(PO.RejQty,'0') as RejQty,
	ISNULL(PO.ReworkQty,'0') as ReworkQty from RouteCardEntry R
	left join PrePOSub PS on R.POType='CustomerPO' and PS.PrePOId=R.PrePoId and PS.ItemId=R.ItemId and PS.IsActive=1 
	left join JobOrderPOSub JS on R.POType='JobOrderPO' and JS.JobOrderPOId=R.PrePoId and JS.JobOrderPOSubId=R.ItemId and JS.IsActive=1 
	left join POProcessQtyDetails PO on PO.RouteEntryId=R.RouteEntryId and PO.RoutLineNo=R.RoutLineNo and PO.IsActive=1 
	inner join OperationMaster O on O.OperationId=R.OperationId and O.IsActive=1
	where R.IsActive=1 and R.POType=@POType and R.PrePOId=@PrePOId and R.ItemId=@ItemId  
	order by R.RoutLineNo asc;
END

ELSE IF @Action='GetItemStoreDtls'
BEGIN
  Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.ItemTypeId end desc,
							 case when (@SortCol =1 and  @SortDir ='asc')  then A.ItemtypeName	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.ItemtypeName end desc,	
			                 case when (@SortCol =2 and  @SortDir ='asc')  then A.PartNo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.PartNo	end desc ,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Description	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Description	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.UnitName end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.UnitName end desc,		
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.Qty end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.Qty end desc
                     ) as RowNum  
					 from (	
         Select IM.ItemTypeId,IT.ItemtypeName,IM.PartNo,IM.Description,U.UnitName,I.Qty,
		 COUNT(*) over() as TotalCount 
	     from ItemStock I
	    INNER JOIN ItemMaster IM ON IM.ItemId=I.ItemId AND IM.IsActive=1
	    INNER JOIN ItemTypeMaster IT ON IT.ItemTypeId = IM.ItemTypeId AND IT.IsActive=1
	    INNER JOIN UnitMaster U ON U.UnitId=IM.UOMId AND U.IsActive=1
	     WHERE I.Isactive=1
	 	    )A where (@SearchString is null  or A.ItemtypeName like '%' +@SearchString+ '%' or
									A.PartNo like '%' + @SearchString+ '%' or 
									A.Description like '%' + @SearchString+ '%' or 
									A.UnitName like '%' + @SearchString+ '%' or
									 A.Qty like '%' +@SearchString+ '%'
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
		

END
ELSE IF @Action='GetMachineSetupTimeDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DPRId end desc,
							 case when (@SortCol =1 and  @SortDir ='asc')  then A.DPRNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.DPRNo end desc,	
			                 case when (@SortCol =2 and  @SortDir ='asc')  then A.DPRDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DPRDate	end desc ,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.POType	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.RouteCardNo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.RouteCardNo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.ItemDescription end desc,
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.ProdEmployee end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.ProdEmployee end desc,	
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.Operation end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.Operation end desc,	
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.MachineCode_Name end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.MachineCode_Name end desc,
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.SettingTime end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.SettingTime end desc,	
							 case when (@SortCol =12 and  @SortDir ='asc')  then A.SettingTimeInMins end asc,
							 case when (@SortCol =12 and  @SortDir ='desc') then A.SettingTimeInMins end desc,	
							 case when (@SortCol =13 and  @SortDir ='asc')  then A.PlannedSetup end asc,
							 case when (@SortCol =13 and  @SortDir ='desc') then A.PlannedSetup end desc
                     ) as RowNum  
					 from (	
							Select D.DPRId , D.DPRNo,D.DPRDate, D.POType,
							ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,E.EmpName as ProdEmployee,
							M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
							D.StartTime + ' To ' + D.EndTime as SettingTime,DATEDIFF(minute, StartTime, EndTime) as 'SettingTimeInMins',
							Cast((SELECT Top 1 setup FROM RouteCardMachine RM WHERE (',' + RTRIM(MachineIds) + ',') LIKE '%,' + cast(D.MachineId as varchar) + ',%' 
									  and RM.RouteEntryId=D.RouteEntryId and RM.RoutLineNo=D.RoutLineNo and RM.IsActive=1) as int)  as 'PlannedSetup',
									  COUNT(*) over() as TotalCount
							 from DPREntry D 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
							inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 														
							where D.IsActive=1 and D.DPRKey='Setting' and @POType in ('',D.POType) and cast(D.DPRDate as date) between cast(@FromDate as date) and cast(@ToDate as date) and @MachineId in (0,D.MachineId)
					    )A where (@SearchString is null  or A.DPRNo like '%' +@SearchString+ '%' or
									A.DPRDate like '%' + @SearchString+ '%' or 	A.POType like '%' + @SearchString+ '%' or 
									A.RouteCardNo like '%' + @SearchString+ '%' or 	A.PONo like '%' + @SearchString+ '%' or  	
									A.PartNo like '%' + @SearchString+ '%' or A.ItemDescription like '%' +@SearchString+ '%' or
									A.ProdEmployee like '%' + @SearchString+ '%' or A.Operation like '%' +@SearchString+ '%' or
									A.MachineCode_Name like '%' + @SearchString+ '%' or A.SettingTime like '%' +@SearchString+ '%' or
									A.PlannedSetup like '%' + @SearchString+ '%' or  A.SettingTimeInMins like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetMachineIdleTimeDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;
        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DPRId end desc,
							 case when (@SortCol =1 and  @SortDir ='asc')  then A.DPRNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.DPRNo end desc,	
			                 case when (@SortCol =2 and  @SortDir ='asc')  then A.DPRDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DPRDate	end desc ,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.POType	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.RouteCardNo end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.RouteCardNo end desc,	
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.ItemDescription end desc,
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.ProdEmployee end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.ProdEmployee end desc,	
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.Operation end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.Operation end desc,	
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.MachineCode_Name end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.MachineCode_Name end desc,
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.ShiftName end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.ShiftName end desc,	
							 case when (@SortCol =12 and  @SortDir ='asc')  then A.IdleTime end asc,
							 case when (@SortCol =12 and  @SortDir ='desc') then A.IdleTime end desc
                     ) as RowNum  
					 from (	
						Select *,  COUNT(*) over() as TotalCount from (
							Select D.DPRId, D.DPRNo,D.DPRDate, D.POType,
							ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,E.EmpName as ProdEmployee,
							M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
							S.ShiftName,D.IdleTime,'' as IdleReason
							from DPREntry D 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
							inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 	
							inner join ShiftMaster S on S.ShiftId=D.ShiftId and S.IsActive=1 													
							where D.IsActive=1  and cast(D.IdleTime as float)>0 and  @POType in ('',D.POType) and cast(D.DPRDate as date) between cast(@FromDate as date) and cast(@ToDate as date) and @MachineId in (0,D.MachineId)
							union all
							Select D.DPRId, D.DPRNo,D.DPRDate, D.POType,
							ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,E.EmpName as ProdEmployee,
							M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
							S.ShiftName,DATEDIFF(minute, SetupTo, QCFrom) as IdleTime,'Waiting For Inspection' as IdleReason  from FirstPieceInspectionMain F
							inner join DPREntry D on D.DPRId=F.DPRId and D.IsActive=1 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
							inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 	
							inner join ShiftMaster S on S.ShiftId=D.ShiftId and S.IsActive=1 
							where F.IsActive=1 and DATEDIFF(minute, SetupTo, QCFrom) >0 and @POType in ('',D.POType) and cast(D.DPRDate as date) between cast(@FromDate as date) and cast(@ToDate as date) and @MachineId in (0,D.MachineId)
							)A
					    )A where (@SearchString is null  or A.DPRNo like '%' +@SearchString+ '%' or
									A.DPRDate like '%' + @SearchString+ '%' or 	A.RouteCardNo like '%' + @SearchString+ '%' or 
									A.PONo like '%' + @SearchString+ '%' or  	A.POType like '%' + @SearchString+ '%' or 
									A.PartNo like '%' + @SearchString+ '%' or A.ItemDescription like '%' +@SearchString+ '%' or
									A.ProdEmployee like '%' + @SearchString+ '%' or A.Operation like '%' +@SearchString+ '%' or
									A.MachineCode_Name like '%' + @SearchString+ '%' or A.ShiftName like '%' +@SearchString+ '%' or
									A.IdleTime like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetAllProdReportDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.DPRId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.DPRKey	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.DPRKey	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.DPRNo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.DPRNo end desc,	
			                 case when (@SortCol =3 and  @SortDir ='asc')  then A.DPRDate	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.DPRDate	end desc ,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.POType	end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PONo	end desc,
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.RouteCardNo end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.RouteCardNo end desc,	
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.PartNo end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.PartNo end desc,	
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.ItemDescription end desc,
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.ProdEmployee end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.ProdEmployee end desc,	
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.Operation end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.Operation end desc,	
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.MachineCode_Name end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.MachineCode_Name end desc,
							 case when (@SortCol =12 and  @SortDir ='asc')  then A.SettingTime end asc,
							 case when (@SortCol =12 and  @SortDir ='desc') then A.SettingTime end desc,	
							 case when (@SortCol =13 and  @SortDir ='asc')  then A.Qty end asc,
							case when (@SortCol =13 and  @SortDir ='desc') then A.Qty end desc
                     ) as RowNum  
					 from (	
							Select D.DPRId ,D.DPRKey, D.DPRNo,D.DPRDate, D.POType,
							ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
							D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,E.EmpName as ProdEmployee,
							M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
							D.StartTime + ' To ' + D.EndTime as SettingTime,D.Qty,
							COUNT(*) over() as TotalCount
							from DPREntry D 
							left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
							left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
							left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
							left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
							inner join EmployeeDetails E on E.EmpId = D.ProdEmpId and E.IsActive =1 
							inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
							inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 														
							where D.IsActive=1  and @POType in ('',D.POType) and @PrePOId in (0,D.PrePoId) and @ItemId in (0,D.ItemId)
							 and cast(D.DPRDate as date) between cast(@FromDate as date) and cast(@ToDate as date) and @MachineId in (0,D.MachineId)
					    )A where (@SearchString is null  or A.DPRNo like '%' +@SearchString+ '%' or A.DPRKey like '%' + @SearchString+ '%' or 
									A.DPRDate like '%' + @SearchString+ '%' or 	A.RouteCardNo like '%' + @SearchString+ '%' or 
									A.PONo like '%' + @SearchString+ '%' or  	A.POType like '%' + @SearchString+ '%' or 
									A.PartNo like '%' + @SearchString+ '%' or A.ItemDescription like '%' +@SearchString+ '%' or
									A.ProdEmployee like '%' + @SearchString+ '%' or A.Operation like '%' +@SearchString+ '%' or
									A.MachineCode_Name like '%' + @SearchString+ '%' or A.SettingTime like '%' +@SearchString+ '%' or
									A.Qty like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetTodayProdDtls'
BEGIN
        Select D.DPRId ,D.DPRKey, D.DPRNo,D.DPRDate, D.POType,
		ISNULL(PM.PrePONo,JM.PONo) as PONo,isnull(I.PartNo,JS.PartNo) as PartNo,isnull(I.Description,JS.ItemName) as ItemDescription,
		D.RouteEntryId as RouteCardNo,'P'+cast(D.RoutLineNo as varchar)+' - ' + O.OperationName as Operation,
		M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
		D.Qty,case when D.ContinueShift='false' then 'Yes' else '' end as ContinueShift,COUNT(*) over() as TotalCount							
		from DPREntry D 
		left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
		left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
		left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
		left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1		
		inner join OperationMaster O on O.OperationId=D.OperationId and O.IsActive=1 
		inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 														
		where D.IsActive=1  AND D.DPRDate=cast(getDate() as date) 
	    ORDER BY D.DPRId desc
END

ELSE IF @Action='GetJWDRejDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.JWID end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.JWNo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.JWNo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.JWDate	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.JWDate end desc,	
			                 case when (@SortCol =3 and  @SortDir ='asc')  then A.InwardNo	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.InwardNo	end desc ,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.InwardDate	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.InwardDate	end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.VendorName	end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.VendorName	end desc,
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.VendorDCNo	end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.VendorDCNo	end desc,
							 case when (@SortCol =7 and  @SortDir ='asc')  then A.VendorDCDate end asc,
							 case when (@SortCol =7 and  @SortDir ='desc') then A.VendorDCDate end desc,	
							 case when (@SortCol =8 and  @SortDir ='asc')  then A.PONo end asc,
							 case when (@SortCol =8 and  @SortDir ='desc') then A.PONo end desc,	
							 case when (@SortCol =9 and  @SortDir ='asc')  then A.PartNo_Description end asc,
							 case when (@SortCol =9 and  @SortDir ='desc') then A.PartNo_Description end desc,
							 case when (@SortCol =10 and  @SortDir ='asc')  then A.RawMaterial end asc,
							 case when (@SortCol =10 and  @SortDir ='desc') then A.RawMaterial end desc,	
							 case when (@SortCol =11 and  @SortDir ='asc')  then A.Process end asc,
							 case when (@SortCol =11 and  @SortDir ='desc') then A.Process end desc,	
							 case when (@SortCol =12 and  @SortDir ='asc')  then A.InwardQty end asc,
							 case when (@SortCol =12 and  @SortDir ='desc') then A.InwardQty end desc,
							 case when (@SortCol =13 and  @SortDir ='asc')  then A.AccQty end asc,
							 case when (@SortCol =13 and  @SortDir ='desc') then A.AccQty end desc,	
							 case when (@SortCol =14 and  @SortDir ='asc')  then A.Rejqty end asc,
							 case when (@SortCol =14 and  @SortDir ='desc') then A.Rejqty end desc,	
							 case when (@SortCol =15 and  @SortDir ='asc')  then A.RejReason end asc,
							 case when (@SortCol =15 and  @SortDir ='desc') then A.RejReason end desc
                     ) as RowNum  
					 from (	
							    Select J.JWID, J.JWNo,J.JWDate,isnull(IM.InwardDCNo,MI.InwardNo) as InwardNo,isnull(IM.InwardDCDate,MI.InwardDate) as InwardDate,
								C.CustomerName as VendorName, isnull(IM.VendorDCNo,MI.RefNo) as VendorDCNo , isnull(IM.VendorDCDate,MI.RefDate) as VendorDCDate,
								ISNULL(PM.PrePONo,JM.PONo) as PONo,
								case when J.POType='CustomerPO' then I.PartNo+'-'+I.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
								RM.CodeNo+'-' + RM.Description as RawMaterial, cast(J.RoutLineNo as varchar)+' - '  + O.OperationName as Process,
								isnull(ID.InwardDCQty,MS.Qty) as InwardQty, J.AccQty,J.RejQty, RJ.Rejection as RejReason,
								Count(*)Over() as TotalCount
								from JobWorkInspection J
								inner join OperationMaster O on O.OperationId=J.OperationId and O.IsActive=1 
								left join PrePOMain PM on J.POType='CustomerPO' and  PM.PrePOId =J.PrePOId and PM.isActive=1
								left join JobOrderPOMain JM on   J.POType='JobOrderPO' and  JM.JobOrderPOId =J.PrePOId and JM.isActive=1
								left join ItemMaster I on J.POType='CustomerPO' and I.ItemId=J.ItemId and I.IsActive=1
								left join RawMaterial RM on J.POType='CustomerPO' and  RM.RawMaterialId =J.RawMaterialId and RM.IsActive=1		
								left join JobOrderPOSub JS on J.POType='JobOrderPO' and JS.JobOrderPOId=J.PrePOId and JS.JobOrderPOSubId=J.ItemId and JS.IsActive=1 
								left join InwardDCMain IM on J.Rework=0 and IM.InwardDCId=J.InwardId and IM.IsActive=1 
								left join MaterialOutInwardMain MI on J.Rework=1 and MI.InwardId=J.InwardId and MI.IsActive=1 
								left join InwardDCSub ID on J.Rework=0 and ID.InwardId=J.InwardId and ID.RouteEntryId=J.RouteEntryId and ID.RoutLineNo=J.RoutLineNo and ID.IsActive=1
								left join MaterialOutInwardSub MS on J.Rework=1 and MS.InwardId=J.InwardId and MS.MaterialOutDCSubId=J.MaterialOutDCSubId and MS.IsActive=1 
								inner join CustomerMaster C on C.CustomerId=case when J.Rework=0 then IM.VendorId else MI.CustomerId end and  C.IsActive=1
								left join RejectionReason RJ on RJ.RejectionReasonId=J.RejReasonId and RJ.IsActive=1 
								where J.IsActive=1 and CAST(ISNULL(J.RejQty,0) as float)>0 and CAST(J.JWDate as date) between CAST(@FromDate as date) and CAST(@ToDate as date)
								and @VendorId in ( 0,case when J.Rework=0 then IM.VendorId else MI.CustomerId end ) and @POType in ('',J.POType)
					    )A where (@SearchString is null  or A.JWNo like '%' +@SearchString+ '%' or A.JWDate like '%' + @SearchString+ '%' or 
									A.InwardNo like '%' + @SearchString+ '%' or 	A.InwardDate like '%' + @SearchString+ '%' or 
									A.VendorName like '%' + @SearchString+ '%' or  	A.VendorDCNo like '%' + @SearchString+ '%' or 
									A.VendorDCDate like '%' + @SearchString+ '%' or A.PONo like '%' +@SearchString+ '%' or
									A.PartNo_Description like '%' + @SearchString+ '%' or A.RawMaterial like '%' +@SearchString+ '%' or
									A.InwardQty like '%' + @SearchString+ '%' or  A.Process like '%' +@SearchString+ '%' or
									A.Accqty like '%' + @SearchString+ '%'  or A.Rejqty like '%' +@SearchString+ '%' or
									A.RejReason like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetPOWiseRejDtls'
BEGIN
       Set @FirstRec=@DisplayStart;
       Set @LastRec=@DisplayStart+@DisplayLength;

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then cast(A.Date as date) end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.POType	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.POType	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.PONo end desc,	
			                 case when (@SortCol =3 and  @SortDir ='asc')  then A.PartNo_Description	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.PartNo_Description	end desc ,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.Process	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.Process	end desc,
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.RejQty	end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.RejQty	end desc,
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.RejReason	end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.RejReason	end desc
                     ) as RowNum  
					 from (	
							Select *,Count(*)Over() as TotalCount from (

								 Select J.JWDate as Date,J.POType, ISNULL(PM.PrePONo,JM.PONo) as PONo,
								case when J.POType='CustomerPO' then I.PartNo+'-'+I.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
								cast(J.RoutLineNo as varchar)+' - '  + O.OperationName as Process,
								J.RejQty, RJ.Rejection as RejReason
								from JobWorkInspection J
								 inner join OperationMaster O on O.OperationId=J.OperationId and O.IsActive=1 
								left join PrePOMain PM on J.POType='CustomerPO' and  PM.PrePOId =J.PrePOId and PM.isActive=1
								left join JobOrderPOMain JM on   J.POType='JobOrderPO' and  JM.JobOrderPOId =J.PrePOId and JM.isActive=1
								left join ItemMaster I on J.POType='CustomerPO' and I.ItemId=J.ItemId and I.IsActive=1
								left join JobOrderPOSub JS on J.POType='JobOrderPO' and JS.JobOrderPOId=J.PrePOId and JS.JobOrderPOSubId=J.ItemId and JS.IsActive=1 
								left join RejectionReason RJ on RJ.RejectionReasonId=J.RejReasonId and RJ.IsActive=1 																							
								where J.IsActive=1 and  cast(isnull(J.RejQty,'0') as float)>0 and @POType in ('',J.POType) and @PrePOId in (0,J.PrePOId) and @ItemId in (0,J.ItemId)
								union all
								Select J.QCDate as Date,J.POType, ISNULL(PM.PrePONo,JM.PONo) as PONo,
								case when J.POType='CustomerPO' then I.PartNo+'-'+I.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
								cast(J.RoutLineNo as varchar)+' - '  + O.OperationName as Process,
								J.RejQty, RJ.Rejection as RejReason
								from IntermediateQC J
								 inner join OperationMaster O on O.OperationId=J.OperationId and O.IsActive=1 
								left join PrePOMain PM on J.POType='CustomerPO' and  PM.PrePOId =J.PrePOId and PM.isActive=1
								left join JobOrderPOMain JM on   J.POType='JobOrderPO' and  JM.JobOrderPOId =J.PrePOId and JM.isActive=1
								left join ItemMaster I on J.POType='CustomerPO' and I.ItemId=J.ItemId and I.IsActive=1
								left join JobOrderPOSub JS on J.POType='JobOrderPO' and JS.JobOrderPOId=J.PrePOId and JS.JobOrderPOSubId=J.ItemId and JS.IsActive=1 
								left join RejectionReason RJ on RJ.RejectionReasonId=J.RejReasonId and RJ.IsActive=1 																							
								where J.IsActive=1 and  cast(isnull(J.RejQty,'0') as float)>0 and @POType in ('',J.POType) and @PrePOId in (0,J.PrePOId) and @ItemId in (0,J.ItemId)
								union all
								Select J.Date as Date,J.POType, ISNULL(PM.PrePONo,JM.PONo) as PONo,
								case when J.POType='CustomerPO' then I.PartNo+'-'+I.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
								cast(J.RouteLineNo as varchar)+' - '  + O.OperationName as Process,
								J.RejQty,''as RejReason
								from ManualProductionEntry J
								inner join RouteCardEntry RC on RC.POType=J.POType and RC.RouteEntryId=J.RouteEntryId and RC.RoutLineNo=J.RouteLineNo and RC.IsActive=1 
								 inner join OperationMaster O on O.OperationId=RC.OperationId and O.IsActive=1 
								left join PrePOMain PM on J.POType='CustomerPO' and  PM.PrePOId =J.PrePOId and PM.isActive=1
								left join JobOrderPOMain JM on   J.POType='JobOrderPO' and  JM.JobOrderPOId =J.PrePOId and JM.isActive=1
								left join ItemMaster I on J.POType='CustomerPO' and I.ItemId=J.ItemId and I.IsActive=1
								left join JobOrderPOSub JS on J.POType='JobOrderPO' and JS.JobOrderPOId=J.PrePOId and JS.JobOrderPOSubId=J.ItemId and JS.IsActive=1 
								where J.IsActive=1 and  cast(isnull(J.RejQty,'0') as float)>0 and @POType in ('',J.POType) and @PrePOId in (0,J.PrePOId) and @ItemId in (0,J.ItemId)
							   )A)A where (@SearchString is null  or A.Date like '%' +@SearchString+ '%' or A.POType like '%' + @SearchString+ '%' or 
									A.PONo like '%' + @SearchString+ '%' or 	A.PartNo_Description like '%' + @SearchString+ '%' or 
									A.RejQty like '%' + @SearchString+ '%' or  	A.RejReason like '%' + @SearchString+ '%' or 
									A.Process like '%' + @SearchString+ '%' 
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetFirstPieceInsDtlsById'
BEGIN
    Select D.POType,ISNULL(PM.PrePONo,JM.PONo) as PONo,D.RouteEntryId as RouteCardNo, isnull(I.PartNo,JS.PartNo) as PartNo,
	isnull(I.Description,JS.ItemName) as ItemDescription,M.MachineCode +' - ' + M.MachineName as MachineCode_Name,
	CONVERT(varchar,cast(D.DPRDate as date),105) as SettingDate,D.StartTime + ' To ' + D.EndTime as SettingTime,
	F.QCDate,F.QCFrom + ' To ' + F.QCTo as QCTime,F.DrgNo,
	F.HEad1,F.Head2,F.HEad3,F.HEad4,F.Head5,F.HEad6
	from FirstPieceInspectionMain F
	inner join DPREntry D on D.DPRId=F.DPRId and D.IsActive=1 
	inner join MachineDetails M on M.MachineId=D.MachineId and M.IsActive=1 
	inner join EmployeeDetails IE on IE.EmpId=F.PreparedBy and IE.IsActive=1 
	left join PrePOMain PM on D.POType='CustomerPO' and  PM.PrePOId =D.PrePOId and PM.isActive=1
	left join PrePOSub PS on D.POType='CustomerPO' and  PS.PrePOId =D.PrePOId  and PS.ItemId=D.ItemId and PS.isActive=1
	left join JobOrderPOMain JM on   D.POType='JobOrderPO' and  JM.JobOrderPOId =D.PrePOId and JM.isActive=1
	left join ItemMaster I on D.POType='CustomerPO' and I.ItemId=D.ItemId and I.IsActive=1
	left join JobOrderPOSub JS on D.POType='JobOrderPO' and JS.JobOrderPOId=D.PrePOId and JS.JobOrderPOSubId=D.ItemId and JS.IsActive=1								
	where F.IsActive=1 AND F.FirstPieceInspId=@FirstPieceInsId

	Select FS.Parameter,FS.Specification,FS.Instrument,FS.ToolSetting,FS.Value1,FS.Value2,FS.Value3,FS.Value4,FS.Value5,FS.Value6
	from FirstPieceInspectionSub FS
	where FS.IsActive=1 and FS.FirstPieceInspId=@FirstPieceInsId
END



COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[ReworkReasonSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReworkReasonSP]
                             (
							 @Action varchar(50)=null,
							 @ReworkReasonId int =0,
							 @Rework varchar(100)=null,
							 @CreatedBy int =0
							 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertReworkReason'
BEGIN
     IF @ReworkReasonId =0
	 BEGIN
	   SET @ReworkReasonId=IsNull((SELECT TOP 1 ReworkReasonId+1 FROM ReworkReason ORDER BY ReworkReasonId desc),1)
	 END
	 ELSE
	 BEGIN
	    UPDATE ReworkReason SET isActive=0 WHERE ReworkReasonId=@ReworkReasonId
	 END
	    INSERT INTO ReworkReason
								(
								ReworkReasonId,
								Rework,
								CreatedBy
								)
						VALUES
							  (
							  @ReworkReasonId,
							  @Rework,
							  @CreatedBy 
							  )
						SELECT '1'							
END
ELSE IF @Action='GetReworkReason'
BEGIN
     SELECT ReworkReasonId, Rework FROM ReworkReason WHERE isActive=1 ORDER BY ReworkReasonId DESC

END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RMMidStockSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RMMidStockSP]
							(
							@Action varchar(75)=null,
							@Date varchar(20)=null,
							@RawMaterialId int =0,
							@MaterialId int =0,
							@Shape varchar(75)=null,
							@OperationId int =0,
							@Text1 varchar(20)=null,
							@Text2 varchar(20)=null,
							@Text3 varchar(20)=null,
							@Value1 varchar(20)=null,
							@Value2 varchar(20)=null,
							@Value3 varchar(20)=null,
							@Qty varchar(20)=null,
							@Dimension VARCHAR(50)=NULL,
						    @CodeNo varchar(50)=null,
							@CreatedBy int =0,
							@OpenStockEntryId int =0
							)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertRMMidStk'
BEGIN
      Set @RawMaterialId=(Select top 1  RawMaterialId from RawMaterial where MaterialId=@MaterialId and Shape=@Shape and Text1 =@Text1 
															and Text2=@Text2 and Value1=@Value1 and isnull(Value2,'')=isnull(@Value2,''))
	IF @RawMaterialId IS NULL
	BEGIN
		 SET @RawMaterialId=isnull((Select top 1 RawMaterialId+1 from RawMaterial order by RawMaterialId desc),1);
		 SET @Dimension =@Value1 +'*' +(case when @Value2='' then '' else @Value2+'*' end ) +  @Value3;
			 INSERT INTO RawMaterial
								 (
								 RawMaterialId,
								 CodeNo,
								 Description,
								 Dimension,
								 MaterialId,
								 Shape,
								 Text1,
								 Text2,
								 Text3,
								 Value1,
								 Value2,
								 Value3,
								 UOMId,
								 PurchaseRate,
								 CreatedBy
								 )
					VALUES
							  (
								 @RawMaterialId,
								 @CodeNo,
								 @CodeNo +' - ' + @Dimension,
								 @Dimension,
								 @MaterialId,
								 @Shape,
								 @Text1,
								 @Text2,
								 @Text3,
								 @Value1,
								 @Value2,
								 @Value3,
								 2,
								 '0.00'
								 ,@CreatedBy
								 )
	END
	ELSE
	BEGIN
	        UPDATE  RMMidStkOpenStock SET IsActive=0  WHERE RawMaterialId=@RawMaterialId AND  OperationId=@OperationId and  
															Text1=@Text1 and Text2=@Text2 and Text3=@Text3 and Value1=@Value1 
															and isnull(Value2,'')=isnull(@Value2,'')  and Value3=@Value3  AND ISACTIVE=1;
		   	 UPDATE  RMMidStock SET IsActive=0  WHERE RawMaterialId=@RawMaterialId AND  OperationId=@OperationId and  
													  Text1=@Text1 and Text2=@Text2 and Text3=@Text3 and Value1=@Value1 
													  and isnull(Value2,'')=isnull(@Value2,'') and Value3=@Value3  AND ISACTIVE=1;
	END

    SET @OpenStockEntryId=ISNULL((SELECT TOP 1 OpenStockEntryId+1 FROM RMMidStkOpenStock ORDER BY OpenStockEntryId DESC),1);
	INSERT INTO [dbo].[RMMidStkOpenStock]
							   ([OpenStockEntryId]
							   ,[Date]
							   ,[RawMaterialId]
							   ,[OperationId]
							   ,[Text1]
							   ,[Text2]
							   ,[Text3]
							   ,[Value1]
							   ,[Value2]
							   ,[Value3]
							   ,[Qty]
							   ,[CreatedBy]
							   )
					VALUES
							  (
							  @OpenStockEntryId,
							  @Date,
							  @RawMaterialId,
							  @OperationId,
							  @Text1,
							  @Text2,
							  @Text3,
							  @Value1,
							  @Value2,
							  @Value3,
							  @Qty,
							  @CreatedBy
							  )
 
   
	  
		INSERT INTO [dbo].[RMMidStock]
									   (
									   [RawMaterialId]
									   ,[OperationId]
									   ,[Text1]
									   ,[Text2]
									   ,[Text3]
									   ,[Value1]
									   ,[Value2]
									   ,[Value3]
									   ,[Qty]
									   ,[CreatedBy]
									   )
							VALUES
									  (
									  @RawMaterialId,
									  @OperationId,
									  @Text1,
									  @Text2,
									  @Text3,
									  @Value1,
									  @Value2,
									  @Value3,
									  @Qty,
									  @CreatedBy
									  )

					SELECT '1'

END
ELSE IF @Action='GetRMMidStkOpenStockDtls'
BEGIN
        SELECT RO.Date, RM.CodeNo, RM.Description,RM.Shape, RM.Dimension,RO.Qty , OperationCode +'-' + OperationName as OperationCode_Name   FROM RMMidstkOpenStock RO
		inner join RawMaterial RM on RM.RawMaterialId=RO.RawMaterialId and RM.IsActive=1 
		inner join OperationMaster O on O.OperationId=RO.OperationId and O.IsActive=1
		where RO.IsActive=1 
		order by RO.OpenStockEntryId desc
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RMPlanningSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RMPlanningSP]
                             (
							 @Action varchar(75)=null,
							 @PrePOId int =0,
							 @CreatedBy int =0,
							 @RmPlanId int =0,
							 @RMPlanning RMPlanning readonly,
							 @Status VARCHAR(20)=NULL
							 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertRMPlanning'
BEGIN
    SET @RmPlanId=isnull((SELECT TOP 1 RmPlanId FROM RMPlanning order by RmPlanId desc),0);
    
		  INSERT INTO [dbo].[RMPlanning]
				   ([RMPlanId]
				   ,[PrePOId]
				   ,[ItemId]
				   ,[RawMaterialId]
				   ,[Text1]
				   ,[Text2]
				   ,[Text3]
				   ,[Value1]
				   ,[Value2]
				   ,[Value3]
				   ,[Weight]
				   ,[CreatedBy]
				   )
		SELECT    
					@RmPlanId + ROW_NUMBER() OVER(ORDER BY (SELECT 1)),
		            @PrePOId
				   ,[ItemId]
				   ,[RawMaterialId]
				   ,[Text1]
				   ,[Text2]
				   ,[Text3]
				   ,[Value1]
				   ,[Value2]
				   ,[Value3]
				   ,[Weight]
				   ,@CreatedBy from @RMPlanning;
			SELECT '1'		  
		 

END
ELSE IF @Action='GetRMPlanningDtlsByPrePOId'
BEGIN
     SELECT PS.PrePOID ,PS.ItemId, PS.Qty, PS.Status,  I.PartNo +'-' + I.Description  as Item, 
     IU.UnitName as IUnitName  ,isnull( RP.RMPlanId,0) as  RMPlanId,isnull( RC.RouteEntryId,0) as  RouteEntryId,  isnull(RP.RawMaterialId,0) as RawMaterialId, RM.Description as RMDescription,
	 RM.Dimension,RU.UnitName as RUnitName,RM.Shape, RM.Text1, RM.Text2 , 
     RM.Text3, RP.Value1, RP.Value2 , RP.Value3,RP.Weight
     FROM PrePOSub PS
	 inner join ItemMaster I on I.ItemId=PS.ItemId and I.IsActive=1 
	 left join unitMaster IU on IU.unitId = I.UOMId and IU.isActive =1
	 left join RMPlanning RP on RP.PrePOId=PS.PrePOId and RP.ItemId =PS.ItemId and RP.IsActive=1 
	 left join (Select RC.RouteEntryId,RC.PrePOId,RC.ItemId from RouteCardEntry RC where RC.IsActive=1 group by RC.RouteEntryId,RC.PrePOId,RC.ItemId)RC on RC.PrePOId=PS.PrePOId and RC.ItemId=PS.ItemId
	 left join RawMaterial RM on RM.RawMaterialId=RP.RawMaterialId and RM.IsActive=1
	 left join unitMaster RU on RU.unitId = RM.UOMId and RU.isActive =1
	 WHERE PS.IsActive=1 AND PS.PrePOId=@PrePOId and ((@Status='NotPlanned' and RP.PrePOId is null) or (@Status='Planned' and  RP.PRePOId=@PrePOID))
END
ELSE IF @Action='GetRMPlanningDtls'
BEGIN
          Select RP.PrePOId,PM.InternalPONo, PM.PrePONo,PM.InternalPODate,CM.CustomerName from RMPlanning RP
		  inner join PrePOMain PM on PM.PrePOId=RP.PrePOId and PM.IsActive=1
		  INNER JOIN CustomerMaster CM ON CM.CustomerId=PM.CustId AND CM.IsActive=1 
		  where RP.IsActive=1 
		  GROUP BY RP.PrePOId,PM.InternalPONo, PM.PrePONo,PM.InternalPODate,CM.CustomerName
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RMPOSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[RMPOSP]
                      (
					  @Action varchar(75)=null,
					  @RMPOId int =0,
					  @RMPONo varchar(20)=null,
					  @Date varchar(20)=null,
					  @ValidDate varchar(20)=null,
					  @SupplierId int  =0 ,
					  @TermsId int =0,
					  @PaymentTermsId int =0,
					  @DespatchThrough varchar(50)=null,
					  @PreparedBy int =0,
					  @TotalAmt varchar(20)=null,
					  @TaxAmt varchar(20)=null,
					  @FreightId int =0,
					  @FreightAmt varchar(20)=null,
					  @ServiceCharge varchar(20)=null,
					  @PackingCharge varchar(20)=null,
					  @CuttingCharge varchar(20)=null,
					  @RoundOff varchar(5)=null,
					  @NetAmt varchar(20)=bull,
					  @SpecialInstruction varchar(max)=null,
					  @IsApproved int =0,
					  @CreatedBy int =0, 
					  @Year VARCHAR(20)=NULL,
					  @RMPOSub RMPOSub READONLY,
					  @SearchString VARCHAR(200)=NULL,
					   @FirstRec INT =0,
					   @LastRec INT =0,
					   @DisplayStart INT =0,
					   @DisplayLength INT =0,
					   @Sortcol INT =0,
					   @SortDir varchar(10)=null,
					   @RouteEntryId int=0,
					   @ViewKey varchar(20)=null,
					   @StockRequestId int =0
					  )
AS
BEGIN 
TRY
BEGIN TRANSACTION
If @Action ='InsertRMPO'
BEGIN
      IF @RMPOId=0
	  BEGIN
	      SET @IsApproved=1;
	      SET @RMPOId=ISNULL((SELECT TOP 1 RMPOId+1 FROM RMPOMain ORDER BY RMPOId DESC),1);
		  SET @RMPONo=(select + cast(CurrentNumber as varchar) + format   from SerialNoFormats where type='PurchaseOrder' and year=@Year)
		  update SerialNoFormats set CurrentNumber=CurrentNumber+1 where type='PurchaseOrder' and year=@Year
	  END
	  ELSE
	  BEGIN
	       SET @IsApproved=0;
	       Update RMPOMain set IsActive=0 where RMPOId=@RMPOId;
	       Update RMPOSub set IsActive=0 where RMPOId=@RMPOId;
	  END
      INSERT INTO [dbo].[RMPOMain]
				   (
				    [RMPOId]
				   ,[RMPONo]
				   ,[Date]
				   ,ValidDate
				   ,[SupplierId]
				   ,[TermsId]
				   ,[PaymentTermsId]
				   ,[DespatchThrough]
				   ,[PreparedBy]
				   ,[TotalAmt]
				   ,[TaxAmt]
				   ,[FreightId]
				   ,[FreightAmt]
				   ,[ServiceCharge]
				   ,[PackingCharge]
				   ,[CuttingCharge]
				   ,[RoundOff]
				   ,[NetAmt]
				   ,[SpecialInstruction]
				   ,[IsApproved]
				   ,[CreatedBy]
				   )
		 VALUES 
		         (
				    @RMPOId
				   ,@RMPONo
				   ,@Date
				   ,@ValidDate
				   ,@SupplierId
				   ,@TermsId
				   ,@PaymentTermsId
				   ,@DespatchThrough
				   ,@PreparedBy
				   ,@TotalAmt
				   ,@TaxAmt
				   ,@FreightId
				   ,@FreightAmt
				   ,@ServiceCharge
				   ,@PackingCharge
				   ,@CuttingCharge
				   ,@RoundOff
				   ,@NetAmt
				   ,@SpecialInstruction
				   ,@IsApproved
				   ,@CreatedBy
				   )
	
		INSERT INTO [dbo].[RMPOSub]
				   ([RMPOId]
				   ,[RMPOLineNo]
				   ,[RawMaterialId]
				   ,[Qty]
				   ,[QtyKgs]
				   ,[Length]
				   ,[GrnBalQty]
				   ,[UnitId]
				   ,[Rate]
				   ,[DiscPercent]
				   ,[DiscountAmt]
				   ,[NetRate]
				   ,[TaxId]
				   ,[TaxAmt]
				   ,[Amount]
				   ,[SpecificationRemarks]
				   ,CreatedBy
				   )
			SELECT 
					@RMPOId , 
					ROW_NUMBER() OVER(ORDER BY (SELECT 1)),
					[RawMaterialId]
				   ,[Qty]
				   ,[QtyKgs]
				   ,[Length]
				   ,[Qty]
				   ,[UnitId]
				   ,[Rate]
				   ,[DiscPercent]
				   ,[DiscountAmt]
				   ,[NetRate]
				   ,[TaxId]
				   ,[TaxAmt]
				   ,[Amount]
				   ,[SpecificationRemarks]
				   ,@CreatedBy FROM @RMPOSub;
	IF @StockRequestId <>0
	BEGIN
	   UPDATE RMStockRequest SET Status='Closed' where StockRequestId=@StockRequestId;
	END

			SELECT '1';  
END
ELSE IF @Action='GetRMPODtls'
BEGIN
     set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;

	Select * into  #GRN from  (	Select distinct GS.RMPOId from GRNSub GS where GS.IsActive=1 )A

        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.RMPOId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.RMPONo	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.RMPONo	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Date	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.Supplier end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.Supplier end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.Terms	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.Terms end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.PaymentTerm end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.PaymentTerm end desc				    
                     ) as RowNum  
					 from (								
						Select RM.RMPOID, RM.RMPONo , RM.Date , C.CustomerName as Supplier , T.Terms , P.PaymentTerm , 
						case when G.RMPOId is  null then 'false' else 'true' end as Status,	COUNT(*) over() as TotalCount 
						from RMPOMain RM
						inner join CustomerMaster C on C.CustomerId=RM.SupplierId and C.IsActive=1 
						left join Terms_ConditionMaster T on T.TermsId=RM.TermsId and T.IsActive=1
						left join PaymentTerms P on P.PaymentId=RM.PaymentTermsId and T.IsActive=1
						left join #GRN G on G.RMPOId =  RM.RMPOId 
						where RM.IsActive=1  and (@ViewKey='View' or RM.IsApproved=0)
						  )A where (@SearchString is null or A.RMPONo like '%' +@SearchString+ '%' or
									A.Date like '%' +@SearchString+ '%' or A.Supplier like '%' +@SearchString+ '%' or
									A.Terms like '%' + @SearchString+ '%' or A.PaymentTerm like '%' +@SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END

Else If @Action='GetRMPODtlsById'
BEGIN
	
Select RMPOId,RMPONo,Date,ValidDate,SupplierId,TermsId,PaymentTermsId,DespatchThrough,PreparedBy,TotalAmt,TaxAmt,FreightId,FreightAmt,ServiceCharge,
PackingCharge,CuttingCharge, RoundOff,NetAmt,SpecialInstruction From RMPOMain Where RMPOId=@RmpoId AND IsActive=1

Select R.RMPOId,R.RMPOLineNo,R.RawMaterialId, R.Qty,R.QtyKgs,R.Length,R.UnitId,R.Rate,R.DiscPercent,R.DiscountAmt,R.NetRate,R.TaxId,
R.TaxAmt,R.Amount,R.SpecificationRemarks,RM.CodeNo,RM.Description,RM.MaterialId,RM.Shape,RM.Value1,RM.Value2 From RMPOSub R
INNER JOIN RawMaterial RM ON RM.RawMaterialId = R.RawMaterialId AND RM.IsActive=1
Where R.RMPOId=@RmpoId AND R.IsActive=1
END
ELSE IF @Action='ApproveRMPO'
BEGIN
   UPDATE RMPOMain SET IsApproved=1 WHERE RMPOId=@RMPOId AND IsActive=1 ;
   Select 1
END



COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RMQCSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RMQCSP]
					  (
					  @Action varchar(75)=null,
					  @GrnId int=0,
					  @RMQCId int =0, 
					  @SupplierId int =0,
					  @CreatedBy int =0,
					  @RMQCNo varchar(20)=null,
					  @RMQCDate varchar(20)=null,
					  @Remarks varchar(max)=null,
					  @Attachments varchar(max)=null,
					  @RMQCSub RMQCSub READONLY,
					  @RMQCDimension RMQCDimension READONLY,
					  @RMDimensionId int =0,
					  @SearchString VARCHAR(200)=NULL,
					  @FirstRec INT =0,
					  @LastRec INT =0,
					  @DisplayStart INT =0,
					  @DisplayLength INT =0,
					  @Sortcol INT =0,
					  @SortDir varchar(10)=null
					  )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='GetPendingRMQCDtls'
BEGIN
     Select GM.GrnId, GM.GRNNo, GM.GRNDate,C.CustomerName as Supplier from GRNMain GM
	inner join CustomerMaster C on C.CustomerId=GM.SupplierId and C.IsActive=1 
	where GM.IsActive=1 and GM.IsInspected=0
	order by GM.GRNId desc
     
END

ELSE IF @Action='GetGRNDetailsForQC'
BEGIN
   IF @RMQCId<>0
   BEGIN       
       Set @GrnId=(SELECT TOP 1 GRNId FROM RMQCMain WHERE IsActive=1 AND RMQCId=@RMQCId);
   END
      Select G.GRNId,G.GRNNo,G.GRNDate,C.CustomerName as 'SupplierName',G.SupplierId
      From GRNMain G 
      INNER JOIN CustomerMaster C ON G.SupplierId=C.CustomerId AND C.IsActive=1
      WHERE G.IsActive=1 AND G.GRNId=@GRnId

      Select G.GRNId,G.RMPOId, G.RawMaterialId,R.Description,RecQty , U.UnitName , RQ.AccQty, RQ.AccQtyKgs, RQ.AccQtyNos, RQ.RejQty, ISNULL(RQ.RejReasonId,0) as RejReasonId,RM.RMQCNo,
	  RM.RMQCDate, RM.Remarks, M.materialName,M.materialId, R.Shape, R.Text1, R.Text2, R.Text3,
	  R.Value1,R.Value2
      From GRNSub G
	  left join RMQCSub RQ on RQ.RMPOId=G.RMPOId and RQ.RawMaterialId=G.RawMaterialId and RQ.IsActive=1 and RQ.RMQCId=@RMQCId
	  left JOIN RMQCMain RM on RM.RMQCId = RQ.RMQCId And RM.IsActive=1
      INNER JOIN RawMaterial R ON R.RawMaterialId= G.RawMaterialId AND R.IsActive=1
      INNER JOIN RMPOSub RS ON RS.RMPOId=G.RMPOId AND G.RawMaterialId=RS.RawMaterialId AND RS.IsActive=1
      INNER JOIN UnitMaster U ON U.UnitId=RS.UnitId AND U.IsActive=1
	  INNER JOIN MaterialMaster M ON M.materialId= R.MaterialId AND M.isActive=1
      WHERE G.IsActive=1 AND G.GRNId=@GrnId;


END
ELSE IF @Action='InsertRMQC'
BEGIN
      IF @RMQCId<>0
	  BEGIN
	       Select * into #ORMQC from (
				Select T.RawMaterialId , T.VendorId, T.MaterialId, T.Shape , T.Text1 , T.Text2, T.Text3, T.Value1, T.Value2, T.Value3,T.UnitWeight, 
				SUM(cast(ISNULL(T.QtyNos,'0') as decimal(18,2))) as QtyNos, SUM(cast(ISNULL(T.QtyKgs,'0') as decimal(18,2))) as QtyKgs
				 from RMQCDimension  T 
				 where T.IsActive=1 and T.RMQCId = @RMQCId
		         group by  T.RawMaterialId , T.VendorId, T.MaterialId, T.Shape , T.Text1 , T.Text2, T.Text3, T.Value1, T.Value2, T.Value3,T.UnitWeight
			  )A;

			 
   Update RM  Set RM.qtynos =cast(ISNULL(RM.qtynos ,'0') as decimal(18,2))- cast(ISNULL(T.qtynos,'0') as decimal(18,2)),
				  RM.QtyKgs =cast(ISNULL(RM.QtyKgs ,'0')  as decimal(18,3)) - cast(ISNULL(T.QtyKgs,'0') as decimal(18,3))
   from RMDimensionWiseStock RM
   inner join #ORMQC T on RM.VendorId=T.VendorId and RM.RawMaterialId = T.RawMaterialId and 
										   RM.MaterialId=T.MaterialId and RM.Shape=T.Shape and RM.Text1=T.Text1 and RM.Text2=T.Text2
										   and RM.Text3=T.Text3 and RM.Value1=T.Value1 and isnull(RM.Value2,'')=isnull(T.Value2,'') and RM.Value3=T.Value3;
				
	        UPDATE RMQCMain SET ISACTIVE=0 WHERE RMQCId =@RMQCId;
	        UPDATE RMQCSub SET ISACTIVE=0 WHERE RMQCId =@RMQCId;
	        UPDATE RMQCDimension SET ISACTIVE=0 WHERE RMQCId =@RMQCId;
			
	  END
	  ELSE
	  BEGIN
	       SET @RMQCId=ISNULL((SELECT TOP 1 RMQCId +1 FROM RMQCMain ORDER BY RMQCId DESC),1);
		   SET @RMQCNo=@RMQCId;
	  END
	  UPDATE GRNMain SET IsInspected=1 WHERE GRNId=@GrnId AND IsActive=1 ;
	     INSERT INTO RMQCMain 
							  (
							  RMQCId,
							  RMQCNo,
							  RMQCDate,
							  GRNId,
							  SupplierId,
							  Remarks,
							  Attachments,
							  CreatedBy
							  )
					VALUES
						    (
							@RMQCId,
							@RMQCNo,
							@RMQCDate,
							@GrnId,
							@SupplierId,
							@Remarks,
							@Attachments,
							@CreatedBy
							)
			 
		INSERT INTO [dbo].[RMQCSub]
				   (
				    [RMQCId]
				   ,[RMPOId]
				   ,[RawMaterialId]
				   ,[AccQty]
				   ,[AccQtyKgs]
				   ,[AccQtyNos]
				   ,[RejQty]
				   ,[RejReasonId]
				   ,[CreatedBy]
				   )
			SELECT  @RMQCId
				   ,[RMPOId]
				   ,[RawMaterialId]
				   ,[AccQty]
				   ,[AccQtyKgs]
				   ,[AccQtyNos]
				   ,[RejQty]
				   ,[RejReasonId]
				   ,@CreatedBy FROM @RMQCSub;

		INSERT INTO [dbo].[RMQCDimension]
						   (
						    [RMQCId]
						   ,[RMPOId]
						   ,[RawMaterialId]
						   ,[IsMoveToVendor]
						   ,[VendorId]
						   ,[MaterialId]
						   ,[Shape]
						   ,[Text1]
						   ,[Text2]
						   ,[Text3]
						   ,[Value1]
						   ,[Value2]
						   ,[Value3]
						   ,[QtyNos]
						   ,[QtyKgs]
						   ,[UnitWeight]
						   ,[CreatedBy]
						   )
				SELECT @RMQCId
						   ,[RMPOId]
						   ,[RawMaterialId]
						   ,[IsMoveToVendor]
						   ,[VendorId]
						   ,[MaterialId]
						   ,[Shape]
						   ,[Text1]
						   ,[Text2]
						   ,[Text3]
						   ,[Value1]
						   ,[Value2]
						   ,[Value3]
						   ,[QtyNos]
						   ,[QtyKgs]
						   ,[UnitWeight]
						   ,@CreatedBy  FROM @RMQCDimension;
   SET @RMDimensionId=ISNULL((select top 1 RMDimensionId  from RMDimensionWiseStock where IsActive=1  order by RMDimensionId desc),0);
   
   Select * into #RMQC from (
        Select T.RawMaterialId , T.VendorId, T.MaterialId, T.Shape , T.Text1 , T.Text2, T.Text3, T.Value1, T.Value2, T.Value3,T.UnitWeight, 
		SUM(cast(ISNULL(T.QtyNos,'0') as decimal(18,2))) as QtyNos, SUM(cast(ISNULL(T.QtyKgs,'0') as decimal(18,2))) as QtyKgs
		 from @RMQCDimension  T
		 group by  T.RawMaterialId , T.VendorId, T.MaterialId, T.Shape , T.Text1 , T.Text2, T.Text3, T.Value1, T.Value2, T.Value3,T.UnitWeight
   )A	  
   
   
   Update RM  Set RM.qtynos =cast(ISNULL(RM.qtynos,'0') as decimal(18,2))+ cast(ISNULL(T.qtynos,'0') as decimal(18,2)),
				  RM.QtyKgs =cast(ISNULL(RM.QtyKgs,'0') as decimal(18,3)) + cast(ISNULL(T.QtyKgs,'0') as decimal(18,3))
   from RMDimensionWiseStock RM
   inner join #RMQC T on RM.VendorId=T.VendorId and RM.RawMaterialId = T.RawMaterialId and 
										   RM.MaterialId=T.MaterialId and RM.Shape=T.Shape and RM.Text1=T.Text1 and RM.Text2=T.Text2
										   and RM.Text3=T.Text3 and RM.Value1=T.Value1 and isnull(RM.Value2,'')=isnull(T.Value2,'') and RM.Value3=T.Value3
  where RM.IsActive=1;

	 INSERT INTO [dbo].[RMDimensionWiseStock]
						   (
						   [RMDimensionId]
						   ,[VendorId]
						   ,[RawMaterialId]
						   ,[MaterialId]
						   ,[Shape]
						   ,[Text1]
						   ,[Text2]
						   ,[Text3]
						   ,[Value1]
						   ,[Value2]
						   ,[Value3]
						   ,[UnitWeight]
						   ,[QtyNos]
						   ,[QtyKgs]
						   ,[CreatedBy]
		                  )
				SELECT 
						  
						  @RMDimensionId + ROW_NUMBER() OVER(ORDER BY (SELECT 1)),
						  T.VendorId,
						  T.RawMaterialId, 
						  T.MaterialId,
						  T.Shape,
						  T.Text1,
						  T.Text2,
						  T.Text3,
						  T.Value1,
						  T.Value2,
						  T.Value3,
						  T.UnitWeight,
						  T.QtyNos,
						  T.QtyKgs,
						  @CreatedBy  FROM #RMQC T 
						  where not exists(Select RMDimensionId from RMDimensionWiseStock RM 
										   where RM.VendorId=T.VendorId and RM.RawMaterialId = T.RawMaterialId and 
										   RM.MaterialId=T.MaterialId and RM.Shape=T.Shape and RM.Text1=T.Text1 and RM.Text2=T.Text2
										   and RM.Text3=T.Text3 and RM.Value1=T.Value1 and isnull(RM.Value2,'')=isnull(T.Value2,'') and RM.Value3=T.Value3 and RM.IsActive=1 )
						 

			SELECT '1' 


END
Else If @Action='GetRmQCDtls'
BEGIN
       set @FirstRec=@DisplayStart;
        set @LastRec=@DisplayStart+@DisplayLength;
					select * ,
					 (Select count(distinct RMQCId)  from RMQCMain where isActive=1) as TotalCount
					from (
					select *,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
					case when   @SortCol =0  then A.RMQCId   end desc,
					case when (@SortCol =1 and  @SortDir ='asc') then A.RMQCNo  end asc,
					case when (@SortCol =1 and  @SortDir ='desc') then A.RMQCNo end desc,
					case when (@SortCol =2 and  @SortDir ='asc')  then A.RMQCDate  end asc,
				    case when (@SortCol =2 and  @SortDir ='desc') then A.RMQCDate  end desc, 
				    case when (@SortCol =3 and  @SortDir ='asc')  then A.grnNo  end asc,
					case when (@SortCol =3 and  @SortDir ='desc')  then A.grnNo end desc,
					case when (@SortCol =4 and  @SortDir ='asc') then A.customername  end asc,
					case when (@SortCol =4 and  @SortDir ='desc') then A.customername end desc,
					case when (@SortCol =5 and  @SortDir ='asc') then A.InspectedBy  end asc,
				    case when (@SortCol =5 and  @SortDir ='desc')then A.InspectedBy end desc,
					case when (@SortCol =6 and  @SortDir ='asc') then A.createdOn  end asc,
				    case when (@SortCol =6 and  @SortDir ='desc')then A.createdOn end desc
					)as RowNum from(
			Select Q.RMQCId,Q.RMQCNo,Q.RMQCDate,Q.Attachments,Q.createdOn,C.customername,'' as InspectedBy,G.grnNo
			From RMQCMain Q
			INNER Join GRNMain G ON G.grnId = Q.grnId AND G.isActive=1
			INNER Join CustomerMaster C ON C.customerId=Q.supplierId AND C.isActive=1
		  --INNER Join userdetails U ON U.UserId = Q.createdBy AND U.IsActive=1
	    	Where Q.isActive=1
			 ) A
 
					 where (@SearchString is null or

							A.RMQCNo like '%' +@SearchString + '%' or
							A.RMQCDate like '%' +@SearchString+ '%' or
							A.Attachments like '%' +@SearchString+ '%' or
							A.createdOn like '%' +@SearchString + '%' or
							A.customername like '%'+@SearchString + '%' or
			                A.InspectedBy like '%'+@SearchString + '%'or
							A.grnNo like '%' +@SearchString + '%'
							))B
							 where  RowNum > @FirstRec and RowNum <= @LastRec
END

Else If @Action='GetRMQCDimensionDetails'
BEGIN
	select R.RMQCId,R.RMPOId,R.RawMaterialId,R.IsMoveToVendor,R.VendorId,R.MaterialId,R.Shape,R.Text1,R.Text2,R.Text3,R.Value1,R.Value2,
	R.Value3,R.QtyNos,R.QtyKgs,R.UnitWeight,M.materialName
	from RMQCDimension R 
	INNER JOIN MaterialMaster M ON M.materialId= R.MaterialId AND M.isActive=1
	WHERE R.IsActive=1 AND R.RMQCId = @RMQCId

END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RMStockRequestSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RMStockRequestSP]
                                (
								@Action varchar(75)=null,
								@StockRequestId int =0,
								@PrePOId int =0 , 
								@Date varchar(20)=null,
								@CreatedBy int =0, 
								@RMStockRequest RMStockRequest READONLY,								
								@SearchString VARCHAR(200)=NULL,
								@FirstRec INT =0,
								@LastRec INT =0,
								@DisplayStart INT =0,
								@DisplayLength INT =0,
								@Sortcol INT =0,
								@SortDir varchar(10)=null,
								@RouteEntryId int=0,
								@ViewKey varchar(20)=null
								)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertRMStockRequest'
BEGIN
      SET @StockRequestId=ISNULL((SELECT TOP 1 StockRequestId+1 FROM RMStockRequest ORDER BY StockRequestId DESC),1);
	  INSERT INTO RMStockRequest
								 (
								 StockRequestId, 
								 PrePOId, 
								 ItemId,
								 Date, 
								 RawMaterialId, 
								 ReqQty,
								 CreatedBy
								 )
					SELECT       @StockRequestId, 
								 @PrePOId, 
								 ItemId,
								 @Date, 
								 RawMaterialId, 
								 ReqQty,
								 @CreatedBy FROM @RMStockRequest;
					SELECT '1'
END
ELSE IF @Action='GetDtlsForRMStkRequest'
BEGIN
        Select RP.ItemId,I.PartNo,I.Description,PS.Qty as POQty,RM.RawMaterialId, RM.CodeNo, RM.Description as RMDescription, 
		RP.Text1,RP.Text2,RP.Text3,RP.Value1,RP.Value2,RP.Value3,RP.Weight,
		cast(cast(RP.Weight as float) * cast(PS.Qty as float) as decimal(18,3)) as TotalWeight,
		 isnull(RW.AvlQty,0) as AvlQty
		from RMPlanning RP
		left join RawMaterial RM on RM.RawMaterialId=RP.RawMaterialId and RM.IsActive=1	 	
		inner join ItemMaster I on I.ItemId=RP.ItemId and I.IsActive=1 
		inner join PrePOSub PS on PS.PrePOId=@PrePOId and PS.ItemId=RP.ItemId and PS.IsActive=1 
		left join (Select RW.RawMaterialId,sum(cast(isnull(RW.QtyKgs,'0') as decimal(18,3))) as AvlQty from RMDimensionWiseStock RW 
				   where RW.IsActive=1 and RW.VendorId=0 group by RW.RawMaterialId) RW on RW.RawMaterialId=RP.RawMaterialId
		where RP.IsActive=1 
END
ELSE IF @Action='GetRMStockRequestDtlsById'
BEGIN
     Select RS.Date, RS.RawMaterialId, RM.CodeNo,RM.Description,RM.Shape,RM.Value1,RM.Value2,sum(cast(isnull(RS.ReqQty,'0') as decimal(18,3))) as ReqQty,
	 RM.PurchaseRate as Rate
	  from RMStockRequest RS
	 inner join RawMaterial RM on RM.RawMaterialId=RS.RawMaterialId and RM.IsActive=1 
	 where RS.IsActive=1 AND RS.StockRequestId=@StockRequestId
	 group by RS.RawMaterialId, RS.Date,RM.CodeNo,RM.Description,RM.Shape,RM.Value1,RM.Value2,RM.PurchaseRate
END
ELSE IF @Action='GetRMStockRequestDtls'
BEGIN
      Set @FirstRec=@DisplayStart;
      Set @LastRec=@DisplayStart+@DisplayLength;
        select * from (
            Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
							 case when @Sortcol=0 then A.StockRequestId end desc,
			                 case when (@SortCol =1 and  @SortDir ='asc')  then A.Date	end asc,
							 case when (@SortCol =1 and  @SortDir ='desc') then A.Date	end desc ,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.PONo	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.PONo	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.ItemDescription end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.ItemDescription end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.RMDescription	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.RMDescription end desc,	
							 case when (@SortCol =5 and  @SortDir ='asc')  then A.ReqQty end asc,
							 case when (@SortCol =5 and  @SortDir ='desc') then A.ReqQty end desc,		
							 case when (@SortCol =6 and  @SortDir ='asc')  then A.Status end asc,
							 case when (@SortCol =6 and  @SortDir ='desc') then A.Status end desc		    
                     ) as RowNum  
					 from (								
						Select RS.StockRequestId, RS.Date,PM.PrePONO AS PONo, I.PartNo +' - '+I.Description as ItemDescription,
						RM.CodeNo +' - '+ RM.Description as RMDescription,RS.ReqQty,RS.Status,COUNT(*) over() as TotalCount  from RMStockRequest RS 
						inner join RawMaterial RM on RM.RawMaterialId=RS.RawMaterialId and RM.IsActive=1 
						inner join PrePOMain PM on PM.PrePOId=RS.PrePOId and PM.IsActive=1 
						inner join ItemMaster I on I.ItemId= RS.ItemId and I.IsActive=1 
						where RS.IsActive=1 
						  )A where (@SearchString is null or A.Date like '%' +@SearchString+ '%' or
									A.PONo like '%' +@SearchString+ '%' or A.ItemDescription like '%' +@SearchString+ '%' or
									A.RMDescription like '%' + @SearchString+ '%' or A.ReqQty like '%' +@SearchString+ '%' or 
									A.Status like '%' + @SearchString+ '%'
									)
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetOpenRMStkRequestDtls'
BEGIN
     SELECT RS.StockRequestId, RS.Date,PM.PrePONo,RS.Status FROM RMStockRequest RS
	 INNER JOIN PrePOMain PM on PM.PrePOId=RS.PrePOId and PM.IsActive=1 
	 WHERE RS.IsActive=1 
	 group by RS.StockRequestId,RS.Date,PM.PrePONo,RS.Status
	 ORDER BY RS.StockRequestId DESC
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RoleSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RoleSP]
					   (
					   @Action varchar(75)=null,
					   @RoleId int =0,
					   @RoleName varchar(50)=null,
					   @MenuIds varchar(5000)=null,
					   @CreatedBy int =0
					   )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertRole'
BEGIN
      IF @RoleId=0
	  BEGIN
	       SET @RoleId=ISNULL((SELECT TOP  1 RoleId+1 FROM RoleMaster ORDER BY RoleId DESC),1);
	  END
	  ELSE
	  BEGIN
	      UPDATE RoleMaster SET IsActive=0 WHERE RoleId=@RoleId;
	  END
	      INSERT INTO RoleMaster
								(
								RoleId,
								RoleName,
								MenuIds,
								CreatedBy
								)
						VALUES
							    (
								@RoleId,
								@RoleName,
								@MenuIds,
								@CreatedBy
								)
					SELECT '1';
END
ELSE IF @Action='GetRoles'
BEGIN
    SELECT RoleId, RoleName, MenuIds FROM RoleMaster WHERE IsActive=1 ORDER BY RoleId DESC
END
ELSE IF @Action='GetMenuDtls'
BEGIN
    SELECT * FROM MenuMaster where isactive=1
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[RouteCardEntrySP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[RouteCardEntrySP]
								(
								@Action varchar(75)=null,
								@RouteEntryId int =0,
								@RoutCardNo varchar(20)=null,
								@POType varchar(20)=null,
								@Date varchar(20)=null,
								@ProcessQty varchar(20)=null,
								@PrePOId int =0,
								@ItemId int =0,
								@RawMaterialId int =0,
								@CreatedBy int =0, 
								@RouteCardEntry RouteCardEntry READONLY,
								@RouteCardMachine RouteCardMachine READONLY,
								@SearchString VARCHAR(200)=NULL,
								@FirstRec INT =0,
								@LastRec INT =0,
								@DisplayStart INT =0,
								@DisplayLength INT =0,
								@Sortcol INT =0,
								@SortDir varchar(10)=null,
								@FromDate varchar(20)=null,
								@ToDate varchar(20)=null,
								@Status varchar(20)=null,
								@Key varchar(20)=null,
								@InspectQty varchar(20)=null

								)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertRoutCardEntry'
BEGIN
     IF @RouteEntryId=0
	 BEGIN
	      SET @Key='Add';
	      SET @RouteEntryId=ISNULL((SELECT TOP 1 RouteEntryId+1 FROM RouteCardEntry ORDER BY RouteEntryId DESC),1);
		  SET @RoutCardNo=@RouteEntryId;
	 END
	 ELSE
	 BEGIN
	      SET @Key='Edit';
	     UPDATE RouteCardEntry SET IsActive=0 WHERE RouteEntryId=@RouteEntryId;
	     UPDATE RouteCardMachine SET IsActive=0 WHERE RouteEntryId=@RouteEntryId;
	 END
	 INSERT INTO [dbo].[RouteCardEntry]
							   (
							   [RouteEntryId]
							   ,[RoutCardNo]
							   ,[POType]
							   ,[Date]
							   ,[ProcessQty]
							   ,[PrePOId]
							   ,[ItemId]
							   ,[RawMaterialId]
							   ,[RoutLineNo]
							   ,[OperationId]
							   ,[Type]
							   ,[PiecesPerHr]
							   ,[ConvFact]
							   ,[WorkPlace]
							   ,[CreatedBy]
							   )
						SELECT @RouteEntryId,
						       @RoutCardNo,
							   @POType,
							   @Date,
							   @ProcessQty, 
							   @PrePOId,
							   @ItemId,
							   @RawMaterialId,
							   [RoutLineNo],
							   [OperationId],
							   [Type],
							   [PiecesPerHr],
							   [ConvFact],
							   [WorkPlace],
							   @CreatedBy from @RouteCardEntry;
     
	 INSERT INTO [dbo].[RouteCardMachine]
							   (
							    [RouteEntryId]
							   ,[RoutLineNo]
							   ,[MachineIds]
							   ,[Setup]
							   ,[Cycle]
							   ,[Handling]
							   ,[Idle]
							   ,[AlterRegular]
							   ,[CreatedBy]
							   )
					 SELECT    @RouteEntryId
					          ,[RoutLineNo]
							   ,[MachineIds]
							   ,[Setup]
							   ,[Cycle]
							   ,[Handling]
							   ,[Idle]
							   ,[AlterRegular]
							   ,@CreatedBy FROM @RouteCardMachine;
IF @PoType='JobOrderPO' and @Key='Add'
BEGIN
    SET @InspectQty =(Select  sum(cast(ISNULL(j.AccQty,'0') as decimal(18,3))) from JobOrderInspectionMain j 
		where J.JobOrderPOId=@prepoId and j.JobOrderPOSubId=@itemId and j.IsActive='1') ;
    INSERT INTO POProcessQtyDetails
								  (
								  POType,
								  PrePOId,
								  ItemId,
								  RouteEntryId,
								  RoutLineNo,
								  TotalAccQty,
								  AccQty,
								  ReworkQty,
								  RejQty,
								  CreatedBy
								  )
						VALUES
								(
								@PoType,
								@PrePOId,
								@ItemId,
								@RouteEntryId,
								1,
								@InspectQty,
								@InspectQty,
								'0',
								'0',
								@CreatedBy
								)

	Update S set S.Status='In Progress' from JobOrderPOSub S
	where S.JobOrderPOId=@PrePOId and S.JobOrderPOSubId=@ItemId;

	Update M set M.Status='In Progress' from JobOrderPOMain M
	where  M.JobOrderPOId=@PrePOId;
	

END
							   SELECT 1

END
Else If @Action='GetPoNoDtlsForRouteCard'
BEGIN
  IF @PoType='CustomerPO'
  BEGIN
		Select PM.PrePONo as PONO, PM.PrePOId from PrePOSub PS
		inner join PrePOMain PM on PM.PrePOId=PS.PrePOId and PM.IsActive=1		
		left join RouteCardEntry RC on RC.POType=@POType and  RC.PrePOId=PS.PrePOId and PS.ItemId=RC.ItemId and RC.IsActive=1
		where PS.IsActive=1 and (RC.RouteEntryId=@RouteEntryId or RC.RouteEntryId is null )
		group by PM.PrePOId, PM.PrePONo
  END
  ELSE
  BEGIN
   	    Select JM.JobOrderPOId as PrePOId, JM.PONo as PONO from JobOrderPOSub JS
		inner join JobOrderPOMain JM on JM.JobOrderPOId=JS.JobOrderPOId and JM.IsActive=1
		left join RouteCardEntry RC on RC.POType=@POType and  RC.PrePOId=JS.JobOrderPOId and JS.JobOrderPOSubId=RC.ItemId and RC.IsActive=1
		where JS.IsActive=1 and (RC.RouteEntryId=@RouteEntryId or RC.RouteEntryId is null )
		group by JM.JobOrderPOId, JM.PONo
  END
END
ELSE IF @Action='GetPOItemDtlsForRouteCard'
BEGIN
    IF @POType='CustomerPO'
	BEGIN
        Select  PS.ItemId , I.PartNo +'-' + I.Description as PartNo_Description , PS.Qty as POQty, R.RawMaterialId from PrePOSub PS	
		inner join ItemMaster I on I.ItemId=PS.ItemId and I.IsActive=1 
		inner join RMPlanning R on R.PRePOId = PS.PRePOID and R.ItemId=PS.ItemId and R.IsActive=1 
		left join RouteCardEntry RC on RC.POType=@POType and  RC.PrePOId=PS.PrePOId and PS.ItemId=RC.ItemId and RC.IsActive=1
		where PS.IsActive=1 AND PS.PrePOId=@PrePOId and (RC.RouteEntryId=@RouteEntryId or RC.RouteEntryId is null )
		group by  PS.ItemId,R.RawMaterialId, I.PartNo, I.Description,  PS.Qty
	END
	ELSE
	BEGIN
	    Select  JS.JobOrderPOSubId as ItemId , JS.PartNo +'-' + JS.ItemName as PartNo_Description, JS.Qty as POQty, JS.JobOrderPOSubId as RawMaterialId from JobOrderPOSub JS	
		inner join (Select JS.JobOrderPOId, JS.JobOrderPOSubId from JobOrderInspectionMain JS where JS.IsActive=1 group by JS.JobOrderPOId, JS.JobOrderPOSubId ) R on R.JobOrderPOId = JS.JobOrderPOId and R.JobOrderPOSubId=JS.JobOrderPOSubId 
		left join RouteCardEntry RC on RC.POType=@POType and  RC.PrePOId=JS.JobOrderPOId and JS.JobOrderPOSubId=RC.ItemId and RC.IsActive=1
		where JS.IsActive=1 AND JS.JobOrderPOId=@PrePOId and (RC.RouteEntryId=@RouteEntryId or RC.RouteEntryId is null )
		group by  JS.JobOrderPOSubId, JS.PartNo, JS.ItemName, JS.Qty
	END
END
ELSE IF @Action='GetRouteCardDtls'
BEGIN
	Set @FirstRec=@DisplayStart;
	Set @LastRec=@DisplayStart+@DisplayLength;

	IF @POType='CustomerPO'
	BEGIN
			select * from (
				Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
								 case when @Sortcol=0 then A.RouteEntryId end  desc,
								 case when (@SortCol =1 and  @SortDir ='asc')  then A.Date	end asc,
								 case when (@SortCol =1 and  @SortDir ='desc') then A.Date	end desc ,
								 case when (@SortCol =2 and  @SortDir ='asc')  then A.RoutCardNo	end asc,
								 case when (@SortCol =2 and  @SortDir ='desc') then A.RoutCardNo	end desc,
								 case when (@SortCol =3 and  @SortDir ='asc')  then A.PrePONo end asc,
								 case when (@SortCol =3 and  @SortDir ='desc') then A.PrePONo end desc,
								 case when (@SortCol =4 and  @SortDir ='asc')  then A.PartNo_Description	end asc,
								 case when (@SortCol =4 and  @SortDir ='desc') then A.PartNo_Description end desc,	
								 case when (@SortCol =5 and  @SortDir ='asc')  then A.ProcessQty end asc,
								 case when (@SortCol =5 and  @SortDir ='desc') then A.ProcessQty end desc				    
						 ) as RowNum  
						 from (								
							Select R.RouteEntryId , R.RoutCardNo,R.Date,R.ProcessQty, PM.PrePONo, I.PartNo +'-' + I.Description as PartNo_Description, 
							R.ApprovalStatus,COUNT(*) over() as TotalCount   from RouteCardEntry R
							inner join PrePOMain PM on PM.PrePOId =R.prepoId and PM.isActive =1
							inner join ItemMaster I on I.ItemId=R.ItemId and I.IsActive=1
							where R.IsActive=1 and R.POType='CustomerPO' and cast(R.Date as date) between cast(@FromDate as date) and cast(@ToDate as date)
							and (@Status is null or R.ApprovalStatus=@Status)
							group by R.RouteEntryId , R.RoutCardNo,R.Date,R.ProcessQty, PM.PrePONo, I.PartNo, I.Description, R.ApprovalStatus
						 )A where (@SearchString is null or A.RoutCardNo like '%' +@SearchString+ '%' or
										A.Date like '%' +@SearchString+ '%' or A.PrePONo like '%' +@SearchString+ '%' or
										A.PartNo_Description like '%' + @SearchString+ '%' or A.ProcessQty like '%' +@SearchString+ '%')
				) A where  RowNum > @FirstRec and RowNum <= @LastRec 
    END
	ELSE
	BEGIN
	      select * from (
				Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by        
								 case when @Sortcol=0 then A.RouteEntryId end  desc,
								 case when (@SortCol =1 and  @SortDir ='asc')  then A.Date	end asc,
								 case when (@SortCol =1 and  @SortDir ='desc') then A.Date	end desc ,
								 case when (@SortCol =2 and  @SortDir ='asc')  then A.RoutCardNo	end asc,
								 case when (@SortCol =2 and  @SortDir ='desc') then A.RoutCardNo	end desc,
								 case when (@SortCol =3 and  @SortDir ='asc')  then A.PrePONo end asc,
								 case when (@SortCol =3 and  @SortDir ='desc') then A.PrePONo end desc,
								 case when (@SortCol =4 and  @SortDir ='asc')  then A.PartNo_Description	end asc,
								 case when (@SortCol =4 and  @SortDir ='desc') then A.PartNo_Description end desc,	
								 case when (@SortCol =5 and  @SortDir ='asc')  then A.ProcessQty end asc,
								 case when (@SortCol =5 and  @SortDir ='desc') then A.ProcessQty end desc				    
						 ) as RowNum  
						 from (								
							Select R.RouteEntryId , R.RoutCardNo,R.Date,R.ProcessQty, JM.PONo as PrePONo, JS.PartNo +'-' + JS.ItemName as PartNo_Description, 
							R.ApprovalStatus, COUNT(*) over() as TotalCount   from RouteCardEntry R
							inner join JobOrderPOMain JM on JM.JobOrderPOId =R.prepoId and JM.isActive =1
							inner join JobOrderPOSub JS on JS.JobOrderPOSubId =R.ItemId and JS.isActive =1
							where R.IsActive=1 and R.POType='JobOrderPO' and cast(R.Date as date) between cast(@FromDate as date) and cast(@ToDate as date)
							and (@Status is null or R.ApprovalStatus=@Status)
							group by R.RouteEntryId , R.RoutCardNo,R.Date,R.ProcessQty, JM.PONo, JS.PartNo, JS.ItemName, R.ApprovalStatus
						 )A where (@SearchString is null or A.RoutCardNo like '%' +@SearchString+ '%' or
										A.Date like '%' +@SearchString+ '%' or A.PrePONo like '%' +@SearchString+ '%' or
										A.PartNo_Description like '%' + @SearchString+ '%' or A.ProcessQty like '%' +@SearchString+ '%')
				) A where  RowNum > @FirstRec and RowNum <= @LastRec 
	END
END
ELSE IF @Action='GetRouteCardDtlsById'
BEGIN
    SELECT R.RoutCardNo, R.Date, R.ProcessQty, R.PrePOId, R.ItemId,R.RawMaterialId, R.RoutLineNo,R.OperationId, R.Type, R.PiecesPerHr, R.ConvFact, R.WorkPlace,
		(select count(DPRId) from DPREntry D where D.RouteEntryId=R.RouteEntryId and D.RoutLineNo=R.RoutLineNo and isactive=1)+  
		(select count(DCId) from DCEntrySub D where D.RouteEntryId=R.RouteEntryId and D.RoutLineNo=R.RoutLineNo and isactive=1)+
		(select count(ManualProdEntryId) from ManualProductionEntry M where M.RouteEntryId=R.RouteEntryId and M.RoutelineNo=R.RoutLineNo and isactive=1)
		 AS Entries
	FROM RouteCardEntry R 
	WHERE R.IsActive=1 AND R.RouteEntryId=@RouteEntryId;

    SELECT R.RoutLineNo, r.MachineIds, R.Setup, R.Cycle, R.Handling, R.Idle, R.AlterRegular FROM RouteCardMachine R 
	WHERE R.IsActive=1 AND R.RouteEntryId=@RouteEntryId;
END
	
ELSE IF @Action='ApproveRouteCard'
BEGIN
	update RouteCardEntry set ApprovalStatus = 'true' where RouteEntryId = @RouteEntryId and IsActive = 1
	Select 1
END							
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[SettingsSp]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[SettingsSp]

	@Action varchar(75) = null,
	@MasterId int=0,
	@Status varchar(20) = null
	As
BEGIN 
TRY
BEGIN TRANSACTION

IF @Action='UpdateSettings'
BEGIN
   UPDATE Settings SET Status=@Status WHERE MasterId=@MasterId;
END

ELSE IF @Action='GetSettingsDtls'
BEGIN
	Select * from Settings Where IsActive=1 order by MasterId Desc
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[ShiftMasterSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ShiftMasterSP]
                              (
							  @Action varchar(20)=null,
							  @ShiftId int =0,
							  @ShiftName varchar(50)=null,
							  @FromTime varchar(20)=null,
							  @ToTime varchar(20)=null,
							  @CreatedBy int=0
							  )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertShift'
BEGIN
    IF @ShiftId=0
	BEGIN
	   SET @ShiftId=ISNULL((SELECT TOP 1 ShiftId+1 FROM ShiftMaster ORDER BY ShiftId DESC),1)
	END
	ELSE
	BEGIN
	   UPDATE ShiftMaster SET IsActive=0 WHERE ShiftId=@ShiftId;
	END
	   INSERT INTO ShiftMaster
							 (
							 ShiftId,
							 ShiftName,
							 FromTime,
							 ToTime,
							 CreatedBy
							 )
					VALUES
							(
							@ShiftId,
							@ShiftName,
							@FromTime,
							@ToTime,
							@CreatedBy
							)
				SELECT '1'
END
ELSE IF @Action='GetShiftDtls'
BEGIN
   SELECT  ShiftId, ShiftName, FromTime, ToTime,left(convert(time, convert(datetime, toTime) - convert(datetime, fromTime)),5)  as 'diff' 
    FROM ShiftMaster WHERE IsActive=1 ORDER BY ShiftId DESC
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[spGetErrorInfo]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create Proc [dbo].[spGetErrorInfo]
as
begin
insert into ExceptionLog(  
ErrorLine, ErrorMessage, ErrorNumber,  
ErrorProcedure, ErrorSeverity, ErrorState,  
DateErrorRaised  
)  
SELECT  
ERROR_LINE () as ErrorLine,  
Error_Message() as ErrorMessage,  
Error_Number() as ErrorNumber,  
Error_Procedure() as 'Proc',  
Error_Severity() as ErrorSeverity,  
Error_State() as ErrorState,  
GETDATE () as DateErrorRaised 
end  





GO
/****** Object:  StoredProcedure [dbo].[StockSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Procedure [dbo].[StockSP]

	@Action Varchar(75)=null,
	@SearchString VARCHAR(200)=NULL,
    @FirstRec INT =0,
    @LastRec INT =0,
    @DisplayStart INT =0,
    @DisplayLength INT =0,
    @Sortcol INT =0,
	@SortDir varchar(10)=null
		                          

As
BEGIN 
TRY
BEGIN TRANSACTION
If (@Action='GetRMStockDtls')
BEGIN
set @FirstRec=@DisplayStart;
Set @LastRec=@DisplayStart+@DisplayLength;
     select * from (
       Select A.*,COUNT(*) over() as filteredCount, ROW_NUMBER() over (order by 
			                 case when (@SortCol in (0,1) and  @SortDir ='asc')  then A.CodeNo	end asc,
			                 case when (@SortCol in (0,1) and  @SortDir ='desc')  then A.CodeNo	end asc,
							 case when (@SortCol =2 and  @SortDir ='asc')  then A.Description	end asc,
							 case when (@SortCol =2 and  @SortDir ='desc') then A.Description	end desc,
							 case when (@SortCol =3 and  @SortDir ='asc')  then A.QtyNos	end asc,
							 case when (@SortCol =3 and  @SortDir ='desc') then A.QtyNos	end desc,
							 case when (@SortCol =4 and  @SortDir ='asc')  then A.QtyKgs	end asc,
							 case when (@SortCol =4 and  @SortDir ='desc') then A.QtyKgs	end desc
                     ) as RowNum  
					 from (
				  Select RW.RawMaterialId ,RM.CodeNo , RM.Description ,sum(cast(ISNULL(RW.QtyNos,'0.0') as decimal(18,2))) as QtyNos,
				  sum(cast(isnull(RW.QtyKgs,'0.00') as decimal(18,3))) as QtyKgs,COUNT(*) over() as TotalCount 
				  from RMDimensionWiseStock RW
				  inner join RawMaterial RM on RM.RawMaterialId=RW.RawMaterialId and RM.IsActive=1
				  where RW.IsActive=1 and RW.VendorId=0 and (cast(isnull(RW.QtyKgs,'0.00') as decimal(18,3)) >CAST('0' as decimal) or cast(isnull(RW.QtyNos,'0.00') as decimal(18,2)) >CAST('0' as decimal))
				  group by RW.RawMaterialId, RM.CodeNo, RM.Description 
	    )A where (@SearchString is null or A.CodeNo like '%' +@SearchString+ '%' or
									A.Description like '%' +@SearchString+ '%' or A.QtyNos like '%' +@SearchString+ '%'
									or A.QtyKgs like '%' +@SearchString+ '%')
			) A where  RowNum > @FirstRec and RowNum <= @LastRec 
END
ELSE IF @Action='GetItemStock'
BEGIN
    SELECT I.ItemId, I.Qty FROM ItemStock I
	WHERE I.IsActive=1 
END


COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[TaxSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TaxSP]
                      (
					  @Action varchar(50)=null,
					  @TaxId int =0,
					  @TaxType varchar(10)=null,
					  @TaxName varchar(20)=null,
					  @TaxValue varchar(10)=null,
					  @CreatedBy int =0
					  )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertTax'
BEGIN
    IF @TaxId=0
	BEGIN
	   SET @TaxId=ISNULL((SELECT TOP 1 TaxId+1 FROM TaxMaster ORDER BY TaxId DESC) , 1);
	END
	ELSE
	BEGIN
	   UPDATE TaxMaster SET IsActive=0 WHERE TaxId=@TaxId;
	END
	   INSERT INTO TaxMaster
	                       (
						   TaxId,
						   TaxType,
						   TaxName,
						   TaxValue,
						   CreatedBy
						   )
					VALUES
					       (
						   @TaxId,
						   @TaxType,
						   @TaxName,
						   @TaxValue,
						   @CreatedBy
						   )
				SELECT '1'
END
ELSE IF @Action='GetTaxDtls'
BEGIN
   SELECT TaxId, TaxName, TaxType, TaxValue FROM TaxMaster WHERE ISACTIVE=1 ORDER BY TaxId desc;
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[Terms_ConditionMasterSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Terms_ConditionMasterSP]
                                     (
									 @Action varchar(75)=null,
									 @TermsId int =0,
									 @Terms varchar(300)=null,
									 @CreatedBy int =0
									 )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertTerms_Conditions'
BEGIN
   IF @TermsId=0
   BEGIN
        SET @TermsId=ISNULL((SELECT TOP 1 TermsId+1 FROM Terms_ConditionMaster ORDER BY TermsId DESC),1)
   END
   ELSE
   BEGIN
      UPDATE Terms_ConditionMaster SET IsActive=0 WHERE TermsId=@TermsId;
   END
      INSERT INTO Terms_ConditionMaster
	                                 (
									 TermsId,
									 Terms,
									 CreatedBy
									 )
							VALUES
							        (
									@TermsId,
									@Terms,
									@CreatedBy
									)
						SELECT '1';
END
ELSE IF @Action='GetTerms_ConditionsDtls'
BEGIN
    SELECT TermsId, Terms FROM Terms_ConditionMaster WHERE IsActive=1 ORDER BY TermsId DESC;
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[UnitMasterSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UnitMasterSP]
                            (
							@Action varchar(50)=null,
							@UnitId int =0,
							@UnitName varchar(20)=null,
							@CreatedBy int=0
							)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertUnit'
BEGIN
   IF @UnitId=0
   BEGIN
      SET @UnitId=isnull((SELECT TOP 1 UnitId+1 FROM UnitMaster ORDER BY UnitId desc),1)
   END
   ELSE
   BEGIN
       UPDATE UnitMaster SET IsActive=0 WHERE UnitId=@UnitId;
   END
       INSERT INTO UnitMaster
	                         (
							 UnitId,
							 UnitName,
							 CreatedBy
							 )
					VALUES
					        (
							@UnitId,
							@UnitName,
							@CreatedBy
							)
				SELECT '1'
END
ELSE IF @Action='GetUnitDtls'
BEGIN
   SELECT UnitId, UnitName FROM UnitMaster WHERE IsActive=1 ORDER BY UnitId DESC
END
COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[VehicleSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[VehicleSP]
						  (
						  @Action varchar(50)=null,
						  @VehicleId int =0,
						  @VehicleNo varchar(30)=null,
						  @VehicleName varchar(50)=null,
						  @OpeningReading varchar(20)=null,
						  @AsOfDate varchar(20)=null,
						  @CreatedBy int=0
						  )
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertVehicle'
BEGIN
     IF @VehicleId=0
	 BEGIN
	   SET @VehicleId=ISNULL((SELECT TOP 1 VehicleId+1 FROM VehicleMaster ORDER BY VehicleId DESC),1);
	 END
	 ELSE
	 BEGIN
	    UPDATE VehicleMaster SET isActive=0 WHERE VehicleId=@VehicleId
	 END
	   INSERT INTO VehicleMaster
							(
							VehicleId,
							VehicleNo,
							VehicleName,
							OpeningReading,
							AsofDate,
							CreatedBy
							)
				VALUES
						 (
						 @VehicleId,
						 @VehicleNo,
						 @VehicleName,
						 @OpeningReading,
						 @AsOfDate,
						 @CreatedBy
						 )
			SELECT '1'
END
ELSE IF @Action='GetVehicleDtls'
BEGIN
      Select A.vehicleId,A.vehicleNo,A.VehicleName,A.OpeningReading,A.AsOfDate,isnull(A.LastUpdatedReading,A.OpeningReading) as LastUpdatedReading ,
      isnull(A.LastUpdatedOn,A.AsOfDate) as LastUpdatedOn from (
					Select V.vehicleId,vehicleNo,V.vehicleName,V.OpeningReading,V.AsOfDate,
					PE.currentKms,
					isnull(MAX(PE.currentKms) OVER (PARTITION BY PE.VehicleId),V.OpeningReading) as LastUpdatedReading,
					isnull(PE.asOfDate,V.AsofDate) as LastUpdatedOn
					from VehicleMaster V
					left join PetrolExpenseDetails PE on PE.vehicleId=V.vehicleId and PE.isActive=1
					where V.isActive=1
	  )A where A.currentKms is null or A.CurrentKms=A.LastUpdatedReading 
	  ORDER BY A.VehicleId desc
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
/****** Object:  StoredProcedure [dbo].[VendorPOSP]    Script Date: 04-01-2023 11:12:13 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[VendorPOSP]
							(
							@Action varchar(75)=null,
							@VendorPOId INT =0,
							@VendorPONo varchar(20)=null,
							@VendorPODate varchar(20)=null,
							@VendorId int =0,
							@POType varchar(20)=null,
							@Remarks varchar(max)=null,
							@CreatedBy int =0,
							@VendorPOSub VendorPOSub READONLY,

							  @SearchString VARCHAR(200)=NULL,
							 @FirstRec INT =0,
							 @LastRec INT =0,
							 @DisplayStart INT =0,
							 @DisplayLength INT =0,
							 @Sortcol INT =0,
							 @SortDir varchar(10)=null
							)
AS
BEGIN 
TRY
BEGIN TRANSACTION
IF @Action='InsertVendorPO'
BEGIN
     IF @VendorPOId=0
	 BEGIN
	     SET @VendorPOId=isnull((SELECT TOP 1 VendorPOId+1 FROM  VendorPOMain ORDER BY VendorPOId desc),1);
		 SET @VendorPONo=@VendorPOId;
	 END
	 ELSE
	 BEGIN
	    UPDATE VendorPOMain SET IsActive=0 WHERE VendorPOId=@VendorPOId;
	    UPDATE VendorPOSub SET IsActive=0 WHERE VendorPOId=@VendorPOId;
	 END
			INSERT INTO VendorPOMain	
								    (
									VendorPOId,
									VendorPONo,
									VendorPODate,
									VendorId,
									POType,
									Remarks,
									CreatedBy
									)
						VALUES
								 (
								    @VendorPOId,
									@VendorPONo,
									@VendorPODate,
									@VendorId,
									@POType,
									@Remarks,
									@CreatedBy
									)
			INSERT INTO [dbo].[VendorPOSub]
								   (
								    [VendorPOId]
								   ,[PrePOId]
								   ,[ItemId]
								   ,[RouteEntryId]
								   ,[RouteLineNo]
								   ,[RawMaterialId]
								   ,[OperationId]
								   ,[Qty]
								   ,[UOM]
								   ,[Rate]
								   ,[TaxId]
								   ,[TaxAmt]
								   ,[Amount]
								   ,[CreatedBy]
								   )
						SELECT     @VendorPOId
								   ,[PrePOId]
								   ,[ItemId]
								   ,[RouteEntryId]
								   ,[RouteLineNo]
								   ,[RawMaterialId]
								   ,[OperationId]
								   ,[Qty]
								   ,[UOM]
								   ,[Rate]
								   ,[TaxId]
								   ,[TaxAmt]
								   ,[Amount]
								   ,@CreatedBy FROM @VendorPOSub;				         


					SELECT '1'
END

ELSE IF @Action='GetVendorPoDtls'
BEGIN
				Select V.VendorPOId,V.VendorPODate ,V.VendorPONo,C.CustomerName as VendorName,
				sum(cast(isnull(VS.Amount,'0') as float)) as Amount
	             from VendorPOMain V 
	             INNER JOIN VendorPOSub VS ON VS.VendorPOId=V.VendorPOId AND VS.IsActive=1
	             INNER JOIN CustomerMaster C ON C.CustomerId=V.VendorId AND C.IsActive=1
				 where V.IsActive=1 and V.POType=@POType
				 group by V.VendorPOId,V.VendorPONo,V.VendorPODate,C.CustomerName
                   
		
END

ELSE IF @Action='GetVendorDtlsById'
BEGIN
	Select VendorPOId,VendorPONo,VendorPODate,VendorId,POType,Remarks from VendorPOMain WHERE POType=@POType AND VendorPOId=@VendorPOId AND IsActive=1

	Select VS.PrePOId,VS.ItemId, 
	case when @POType='CustomerPO' then IM.PartNo+'-'+IM.Description else JS.PartNo+'-'+JS.ItemName end  as PartNo_Description,
	VS.RouteEntryId,VS.RouteLineNo,VS.OperationId,
	cast(VS.RouteLineNo as varchar)+'-'+O.OperationName as Operation,VS.RawMaterialId,
	RM.Description as RawMaterialName,VS.qty,Vs.Rate,isnull(VS.TaxId,0) as TaxId,
	VS.TaxAmt,VS.Amount,isnull(PS.Qty,JS.Qty) as POQty,RC.ProcessQty
	from VendorPOSub VS
	left join ItemMaster IM on @POType='CustomerPO' and IM.ItemId=VS.ItemId and IM.IsActive=1
	left join RawMaterial RM on @POType='CustomerPO' and  RM.RawMaterialId =VS.RawMaterialId and RM.IsActive=1 
	inner join OperationMaster O on O.OperationId=VS.OperationId and O.IsActive=1
	left join JobOrderPOSub JS on @POType='JobOrderPO' and JS.JobOrderPOId=VS.PrePOId and JS.JobOrderPOSubId=VS.ItemId and JS.IsActive=1 
	left join PrePOSub PS on @POType='CustomerPO' and PS.PrePOId =VS.PrePOId and PS.ItemId=VS.ItemId and PS.IsActive=1 
	inner join RouteCardEntry RC on RC.RouteEntryId=VS.RouteEntryId and RC.RoutLineNo=VS.RouteLineNo and RC.IsActive=1 
	where VS.IsActive=1 and VS.VendorPOId=@VendorPOId;
END

COMMIT  TRANSACTION
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION
EXEC dbo.spGetErrorInfo  
END CATCH

GO
