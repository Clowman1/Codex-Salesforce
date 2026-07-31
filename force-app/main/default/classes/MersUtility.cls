/**
 * Created by MSI Laptop on 8/5/2022.
 */

public with sharing class MersUtility {
    public class InvocableRequest{
        @InvocableVariable
        public String numberRepresentation;
    }
    @InvocableMethod(Label='Generate Mers')
    public static List<String> generateMers(List<InvocableRequest> requests){
        List<String> mers = new List<String>();
        for(InvocableRequest req : requests){
            String [] numbers = req.numberRepresentation.split('');
            Boolean isOddNumber = Math.mod(numbers.size(), 2) == 0 ? false : true;
            Integer checkDigit = generateCheckDigit(numbers,isOddNumber);
            String mersNumber =  req.numberRepresentation += String.valueOf(checkDigit);
            System.debug(mersNumber);
            mers.add(mersNumber);
        }
        return mers;
    }

    public static Integer generateCheckDigit(List<String> numbers, Boolean isOddNumber){
        Integer carry = 0;
        Integer sumOfNumbers = 0;
        for(Integer i = numbers.size(); i > 0; i--){
            if((Math.mod(i,2) == 1 && isOddNumber) || (Math.mod(i,2) == 0 && !isOddNumber)){
                Integer currentNumber = Integer.valueOf(numbers[i-1]);
                currentNumber = currentNumber * 2;
                if(currentNumber >= 10){
                    currentNumber = Math.mod(currentNumber, 10) + carry;
                    carry = 1;
                }
                else{
                    currentNumber = currentNumber + carry;
                    carry = 0;
                }
                sumOfNumbers += currentNumber;
            }
            else{
                sumOfNumbers += Integer.valueOf(numbers[i-1]);
            }
        }
        sumOfNumbers += carry;
        Integer roundedNumber = sumOfNumbers;
        if(Math.mod(sumOfNumbers,10) > 0){
            roundedNumber = sumOfNumbers + 10 - Math.mod(sumOfNumbers,10);
        }
        Integer checkDigit = roundedNumber-sumOfNumbers;
        System.debug(checkDigit);
        return checkDigit;
    }

}