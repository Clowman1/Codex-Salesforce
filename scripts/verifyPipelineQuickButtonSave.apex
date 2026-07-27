List<PipelineCommandCenterController.QuickButton> buttons = new List<PipelineCommandCenterController.QuickButton>{
    new PipelineCommandCenterController.QuickButton('Processor Review Pipeline', 'Transaction__c', 'Copy_of_Open_Pipeline_Processor'),
    new PipelineCommandCenterController.QuickButton('QC Info Review Pipeline', 'Transaction__c', 'QC_Info_Review_Pipeline'),
    new PipelineCommandCenterController.QuickButton('Biz Dev Team - Working Leads', 'Lead', 'Biz_Dev_Team_Working_Leads')
};

List<PipelineCommandCenterController.QuickButton> savedButtons = PipelineCommandCenterController.saveUserQuickButtons(buttons);
System.debug(JSON.serialize(savedButtons));
