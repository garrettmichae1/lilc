import Foundation

/// Optional first-hour C programs. Data, not a textbook.
struct FirstHourLesson: Identifiable, Equatable, Sendable {
    let id: String
    let number: Int
    let title: String
    let goal: String
    let fileName: String
    let source: String
    let expectedOutput: String

    var relativePath: String { "lessons/\(fileName)" }
}

enum FirstHourCurriculum {
    static let id = "first-hour"
    static let title = "First hour"
    static let summary =
        "Six tiny C programs. Open one, press Run, change a number, press Run again. Optional — skip any lesson."

    static var first: FirstHourLesson { lessons[0] }

    static func lesson(id: String) -> FirstHourLesson? {
        lessons.first { $0.id == id }
    }

    static func lesson(number: Int) -> FirstHourLesson? {
        lessons.first { $0.number == number }
    }

    static let lessons: [FirstHourLesson] = [
        FirstHourLesson(
            id: "hello",
            number: 1,
            title: "Hello",
            goal: "Print a line.",
            fileName: "01-hello.c",
            source: """
            #include <stdio.h>

            /* Lesson 1 of 6 — Hello.
               Press RUN. Change the message, then RUN again. */

            int main(void) {
                printf("hello from lilC\\n");
                return 0;
            }

            """,
            expectedOutput: "hello from lilC\n"
        ),
        FirstHourLesson(
            id: "variables",
            number: 2,
            title: "Variables",
            goal: "Store a number and print it.",
            fileName: "02-variables.c",
            source: """
            #include <stdio.h>

            /* Lesson 2 of 6 — Variables.
               Change year and press RUN. */

            int main(void) {
                int year = 2026;
                printf("year = %d\\n", year);
                return 0;
            }

            """,
            expectedOutput: "year = 2026\n"
        ),
        FirstHourLesson(
            id: "if",
            number: 3,
            title: "If",
            goal: "Choose between two prints.",
            fileName: "03-if.c",
            source: """
            #include <stdio.h>

            /* Lesson 3 of 6 — If.
               Change temp and press RUN. Try 15. */

            int main(void) {
                int temp = 28;
                if (temp >= 20) {
                    printf("warm\\n");
                } else {
                    printf("cool\\n");
                }
                return 0;
            }

            """,
            expectedOutput: "warm\n"
        ),
        FirstHourLesson(
            id: "loop",
            number: 4,
            title: "Loop",
            goal: "Repeat a print.",
            fileName: "04-loop.c",
            source: """
            #include <stdio.h>

            /* Lesson 4 of 6 — Loop.
               Change the 5 to 3 and press RUN. */

            int main(void) {
                int n;
                for (n = 1; n <= 5; n = n + 1) {
                    printf("%d\\n", n);
                }
                return 0;
            }

            """,
            expectedOutput: "1\n2\n3\n4\n5\n"
        ),
        FirstHourLesson(
            id: "array",
            number: 5,
            title: "Array",
            goal: "Add numbers in a list.",
            fileName: "05-array.c",
            source: """
            #include <stdio.h>

            /* Lesson 5 of 6 — Array.
               Change a value in nums and press RUN. */

            int main(void) {
                int nums[4];
                int i;
                int sum;
                nums[0] = 2;
                nums[1] = 4;
                nums[2] = 6;
                nums[3] = 8;
                sum = 0;
                for (i = 0; i < 4; i = i + 1) {
                    sum = sum + nums[i];
                }
                printf("%d\\n", sum);
                return 0;
            }

            """,
            expectedOutput: "20\n"
        ),
        FirstHourLesson(
            id: "function",
            number: 6,
            title: "Function",
            goal: "Give a name to a calculation.",
            fileName: "06-function.c",
            source: """
            #include <stdio.h>

            /* Lesson 6 of 6 — Function.
               Change 21 and press RUN. */

            int twice(int n) {
                return n * 2;
            }

            int main(void) {
                printf("%d\\n", twice(21));
                return 0;
            }

            """,
            expectedOutput: "42\n"
        ),
    ]
}
