/**
 * @author Andrei Karanko
 * @date 3/7/2024
 * @description - This class is a helper class for parsing JSON from Twilio
 * startDelimiter is used to find the body of the message in the JSON string. Can be set externally.
 * Quote replacement is used to escape quotes in the body of the message. Can be set externally.
 */
public with sharing class NCS_JSONParserHelper {
    public static String startDelimiter = '"body":';
    public static String quotesReplacement = '';
    private static final String LOOK_AHEAD_END_DELIMITERS = '(?=","|"})';

    /**
     * - This method is used to escape quotes in the body of the message
     * - (?s) - This is a flag that allows the dot to match all characters including new lines
     * @param jsonString - The JSON string to escape quotes in
     * @return - The JSON string with quotes escaped
     */
    public static String escapeQuotesInBody(String jsonString) {
        Pattern pattern = Pattern.compile('(?s)' + startDelimiter + '"(.*?)' + LOOK_AHEAD_END_DELIMITERS);
        String result = jsonString;

        Matcher matcher = pattern.matcher(jsonString);

        if (!matcher.find()) {
            throw new JSONParserHelperException('No match found in JSON string.');
        }

        matcher.reset();

        while (matcher.find()) {
            String body = matcher.group(1);
            String escapedBody = body;
            if (escapedBody.contains('"')){
                escapedBody = escapedBody.replace('"', quotesReplacement);
            }
            if (escapedBody.contains('\r\n')){
                escapedBody = escapedBody.replace('\r\n', '\\\\r\\\\n');
            }
            if (escapedBody.contains('\n')){
                escapedBody = escapedBody.replace('\n', '\\\\n');
            }
            if (escapedBody.contains('\r')){
                escapedBody = escapedBody.replace('\r', '\\\\r');
            }
            if (escapedBody.contains('\t')){
                escapedBody = escapedBody.replace('\t', '\\\\t');
            }
            result = result.replace(body, escapedBody);
        }

        return result;
    }

    public class JSONParserHelperException extends Exception {
    }
}