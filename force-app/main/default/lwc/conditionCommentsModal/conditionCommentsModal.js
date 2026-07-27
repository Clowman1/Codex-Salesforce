import LightningModal from 'lightning/modal';
import { api } from 'lwc';

export default class ConditionCommentsModal extends LightningModal {
    @api conditionId;
    @api portal = false;
}