public class FormattingUtility {
    public static String formatPhone(String phone){
        String invalidNumbers = '[^0-9]';
        if(phone == null){
            return null;
        }
        phone = phone.replaceAll(invalidNumbers,'');
        if(phone.length() == 10){
            phone = '(' + phone.substring(0,3) + ') ' + phone.substring(3,6) + '-' + phone.substring(6,10);
            System.debug(phone);
        }else if(phone.length() == 11){
            phone = '(' + phone.substring(1,4) + ') ' + phone.substring(4,7) + '-' + phone.substring(7,11);
        }else{
            phone = phone;
        }
        return phone;
    }
}