USE ['DATABASE']
GO

/****** Object:  StoredProcedure [dbo].[zendeskIntegration_Get_Company_Type_SP]    Script Date: 31-08-2015 15:30:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author: https://github.com/larssb
-- Create date: 150831
-- Description:	This sproc gathers the primary phone number of a NAV application customer. This could be c50214, c52015, NAV2013R2 and so forth.
-- It is called by the PowerShell determineCompanyTypeTagIt().
-- =============================================
CREATE PROCEDURE [dbo].[zendeskIntegration_Get_Company_Type_SP] 
	-- Add the parameters for the stored procedure here
	@guid nvarchar(max) 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT TOP 1 CustType
	FROM ['DATABASE'].[dbo].[Transaction_Custtype_View]
	WHERE [Guid] = @guid
	ORDER BY period DESC
END

GO
