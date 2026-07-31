public class TaskTriggerHandler {
	private Map<Id, Lead> LeadsToUpdateMap = new Map<Id, Lead>();

    public void afterInsert(List<Task> newTasks) {
		List<Task> calls = getFilteredCalls(newTasks);
		Set<Id> whoIds = getWhoIds(calls);
		Map<Id, Lead> leadsMap = getLeadsMap(whoIds);
		changeLeadStatus(calls, leadsMap, new Map<Id, Task>());
		setLeadsCallCount(whoIds);
		update this.LeadsToUpdateMap.values();
		updateContactLastActivityDate(newTasks);
	}

	public void afterUpdate(List<Task> newTasks, Map<Id, Task> oldTasksMap) {
		List<Task> calls = getFilteredCalls(newTasks);
		Set<Id> whoIds = getWhoIds(newTasks);
		Map<Id, Lead> leadsMap = getLeadsMap(whoIds);
		changeLeadStatus(newTasks, leadsMap, oldTasksMap);
		update this.LeadsToUpdateMap.values();
	}

	public void afterDelete(List<Task> oldTasks) {
		List<Task> calls = getFilteredCalls(oldTasks);
		Set<Id> whoIds = getWhoIds(calls);
		List<Lead> leadsToUpdate = setLeadsCallCount(whoIds);
		update this.LeadsToUpdateMap.values();
	}

	private static List<Task> getFilteredCalls(List<Task> tasks) {
		List<Task> calls = new List<Task>();

		for (Task taskToFilter :tasks) {
			if (taskToFilter.TaskSubtype == 'Call') {
				calls.add(taskToFilter);
			}
		}

		return calls;
	}

	private static Set<Id> getWhoIds(List<Task> tasks) {
		Set<Id> whoIds = new Set<Id>();

		for (Task task :tasks) {
			whoIds.add(task.WhoId);
		}

		return whoIds;
	}

	private static Map<Id, Lead> getLeadsMap(Set<Id> leadIds) {
		return new Map<Id, Lead>([
			SELECT Id, Status
			FROM Lead
			WHERE Id IN :leadIds
		]);
	}

	private void changeLeadStatus(List<Task> newTasks, Map<Id, Lead> leadsMap, Map<Id, Task> oldTasksMap) {
		for (Task newTask :newTasks) {
			if (!shouldChangeStatus(newTask, leadsMap, oldTasksMap)) {
				continue;
			}

			Lead relatedLead = leadsMap.get(newTask.whoId);

			if (newTask.Subject.contains('Call - No Contact')) {
				handleNoContactStatusChange(relatedLead);
				continue;
			}

			if (newTask.Subject.contains('Contacted/Call Back')) {
				handleContactedStatusChange(relatedLead);
				continue;
			}

			handleOtherStatusChange(newTask.Subject, relatedLead);
		}
	}

	private Boolean shouldChangeStatus(Task newTask, Map<Id, Lead> leadsMap, Map<Id, Task> oldTasksMap) {
		return leadsMap.containsKey(newTask.whoId) && (
			!oldTasksMap.containsKey(newTask.Id) || newTask.Subject != oldTasksMap.get(newTask.Id).Status
		);
	}

	private void handleNoContactStatusChange(Lead relatedLead) {
		if (relatedLead.Status == 'New') {
			if (!this.LeadsToUpdateMap.containsKey(relatedLead.Id)) {
				this.LeadsToUpdateMap.put(relatedLead.Id, new Lead(Id = relatedLead.Id));
			}
	
			Lead leadToUpdate = this.LeadsToUpdateMap.get(relatedLead.Id);
			leadToUpdate.Status = 'Contact Attempt 1';
			this.LeadsToUpdateMap.put(leadToUpdate.Id, leadToUpdate);
			return;
		} 
		
		if (relatedLead.Status.contains('Contact Attempt')) {
			Integer attempts = Integer.valueOf(relatedLead.Status.right(1));

			if (!this.LeadsToUpdateMap.containsKey(relatedLead.Id)) {
				this.LeadsToUpdateMap.put(relatedLead.Id, new Lead(Id = relatedLead.Id));
			}
	
			Lead leadToUpdate = this.LeadsToUpdateMap.get(relatedLead.Id);
			leadToUpdate.Status = 'Contact Attempt ' + ++attempts;
			this.LeadsToUpdateMap.put(leadToUpdate.Id, leadToUpdate);
		}
	}

	private void handleContactedStatusChange(Lead relatedLead) {
		if (relatedLead.Status == 'New' || relatedLead.Status.contains('Contact Attempt')) {
			if (!this.LeadsToUpdateMap.containsKey(relatedLead.Id)) {
				this.LeadsToUpdateMap.put(relatedLead.Id, new Lead(Id = relatedLead.Id));
			}
	
			Lead leadToUpdate = this.LeadsToUpdateMap.get(relatedLead.Id);
			leadToUpdate.Status = 'Contacted/Call Back';
			this.LeadsToUpdateMap.put(leadToUpdate.Id, leadToUpdate);
		}
	}

	private void handleOtherStatusChange(String subject, Lead relatedLead) {
		Map<String, String> statusesMap = new Map<String, String>{
			'30 Day Follow Up' => '30 Day + Follow Up',
			'Call Preapproved' => 'Pre-Approval',
			'Call - Working' =>  'Working',
			'Call - Application' => 'Application',
			'Call - Docs Requested' => 'Documents Requested',
			'Call - Docs Received' => 'Documents Received for Review',
			'Call - Nurturing' => 'Nurturing',
			'Nurture - Preapproval' => 'Nurture - Preapproval',
			'Under Contract' => 'Under Contract',
            'Credit Repair' => 'Credit Repair'
		};

		if (!statusesMap.containsKey(subject.split(' on')[0])) {
			return;
		}

		if (!this.LeadsToUpdateMap.containsKey(relatedLead.Id)) {
			this.LeadsToUpdateMap.put(relatedLead.Id, new Lead(Id = relatedLead.Id));
		}

		Lead leadToUpdate = this.LeadsToUpdateMap.get(relatedLead.Id);
		leadToUpdate.Status = statusesMap.get(subject.split(' on')[0]);
		this.LeadsToUpdateMap.put(leadToUpdate.Id, leadToUpdate);
	}

	private List<Lead> setLeadsCallCount(Set<Id> whoIds) {
		Set<Id> leadIds = filterLeadIds(whoIds);
		return getLeadWithChangedCallCount(leadIds);
	}
	
	private Set<Id> filterLeadIds(Set<Id> whoIds) {
		Set<Id> leadIds = new Set<Id>();
		//////////////////////////////////
		for (Id whoId :whoIds) {
			try{
				if(whoId?.toString()?.startsWith('00Q')) {
				leadIds.add(whoId);
			}
			} catch (Exception e){
				System.debug(e.getMessage());
			}

		}
		//////////////////////////////////
		return leadIds;
	}

	private List<Lead> getLeadWithChangedCallCount(Set<Id> leadIds) {
		List<Lead> leadsToUpdate = new List<Lead>();
	
		List<AggregateResult> ars = [
			SELECT Count(Id) callCount, WhoId
			FROM Task
			WHERE WhoId IN :leadIds
			GROUP BY WhoId
		];

		Map<Id, Integer> leadToCallCountMap = new Map<Id, Integer>();

		for (AggregateResult ar :ars) {
			Id whoId = (Id) ar.get('WhoId');
			Integer callCount = (Integer) ar.get('callCount');
			leadToCallCountMap.put(whoId, callCount);
		}

		for (Id leadId :leadIds) {
			if (!this.LeadsToUpdateMap.containsKey(leadId)) {
				this.LeadsToUpdateMap.put(leadId, new Lead(Id = leadId));
			}
	
			Integer callCount;
		
			if (!leadToCallCountMap.containsKey(leadId)) {
				callCount = 0;
			} else {
				callCount = leadToCallCountMap.get(leadId);
			}

			Lead leadToUpdate = this.LeadsToUpdateMap.get(leadId);
			leadToUpdate.Number_of_Calls__c = callCount;
			this.LeadsToUpdateMap.put(leadId, leadToUpdate);
		}

		return leadsToUpdate;
	}

	private static void updateContactLastActivityDate(List<Task> newTasks){
		try{
			Set<Id> userIds = new Set<Id>();
			for(Task t: newTasks){
				if(t.OwnerId != null && t.OwnerId.getSObjectType().getDescribe().getName() == 'User'){
					userIds.add(t.OwnerId);
				}
			}
			List<User> usersForUpdate = new List<User>();

			for(Id userId: userIds){
				usersForUpdate.add(new User(
					Id = userId,
					Last_Activity_DateTime__c = Datetime.now()
				));
			}
			update usersForUpdate;
		} catch(Exception e){
			System.debug(e.getMessage());
		}
	}
}