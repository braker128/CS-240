import java.util.Scanner;

public class NumberBaseConverter {
    // Build a number-base converter supporting binary, decimal, octal, and hexadecimal.
    public static void main(String[] args) {
        Scanner in = new Scanner(System.in);

        System.out.print("Enter a number: ");
        String input = in.nextLine();
        System.out.print("Enter number base to convert FROM (2, 8, 10, or 16): ");
        int inBase = in.nextInt();
        System.out.print("Enter number base to convert TO (2, 8, 10, or 16): ");
        int outBase = in.nextInt();

        
        // input value is converted to decimal
        String decimalInput = inputToDecimal(input, inBase);
        // System.out.println("Decimal number: " + decimalInput);

        // decimal value passed to convertNumber() to convert to specified base
        String convertOutput = convertNumber(decimalInput, outBase);
        // System.out.println("Converted number: " + convertOutput);
        
        
        if (convertOutput.equals("invalid num") || decimalInput.equals("invalid num")) {
            System.out.println("Number too large or invalid number/base.");
        } else {
            System.out.println("The base " + inBase + " number \"" + input + "\" in base " + outBase + " is: " + convertOutput);
        }

    }

    // Convert the input number to decimal
    public static String inputToDecimal(String input, int inBase) {
       try { 
            switch (inBase) {
                case 2:
                    return Integer.toString(Integer.parseInt(input, 2));
                case 8:
                    return Integer.toString(Integer.parseInt(input, 8));
                case 10:
                    return input;
                case 16:
                    return Integer.toString(Integer.parseInt(input.toUpperCase(), 16));
                default:
                    return "invalid num";
            }
        } catch (NumberFormatException e) {
            return "invalid num";
        }
    }

    // Convert the input number to the specified base
    public static String convertNumber(String input, int outBase){
        try {    
            switch (outBase) {
                case 2:
                    return Integer.toBinaryString(Integer.parseInt(input));
                case 8:
                    return Integer.toOctalString(Integer.parseInt(input));
                case 10:
                    return Integer.toString(Integer.parseInt(input));
                case 16:
                    return Integer.toHexString(Integer.parseInt(input)).toUpperCase();
                default:
                    return "invalid num";
                }
        } catch (NumberFormatException e) {
            return "invalid num";
        }
    }
}




