import { LightningElement, track, wire } from 'lwc';
import getUsersWithAuthUrl from '@salesforce/apex/RingCentralUserAuthController.getUsersWithAuthUrl';

export default class RingCentralUserAuth extends LightningElement {
    @track users = [];

    connectedCallback() {
        getUsersWithAuthUrl().then((data) => {
            this.users = data;
        })
    }


    handleLogin(event) {
        const url = event.target.dataset.url;
        if (url) {
            window.open(url, '_blank'); // open OAuth login in new tab
        }
    }

}