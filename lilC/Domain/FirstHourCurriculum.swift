import Foundation

struct FirstHourLesson: Identifiable, Equatable, Sendable {
    let id: String
    let track: LessonTrack
    let number: Int
    let title: String
    let goal: String
    let fileName: String
    let printHint: String
    let requireSource: [String]
    let requireAnySource: [String]
    let win: LessonWin
    let source: String
    let solution: String

    var relativePath: String {
        switch track {
        case .firstHour: "lessons/\(fileName)"
        case .challenge: "challenges/\(fileName)"
        }
    }

    var kicker: String {
        switch track {
        case .firstHour:
            "Lesson \(number) of \(FirstHourCurriculum.firstHour.count)"
        case .challenge:
            "Challenge \(number) of \(FirstHourCurriculum.challenges.count)"
        }
    }
}

enum FirstHourCurriculum {
    static let title = "Learn"
    static let challengeTitle = "Challenges"

    static var first: FirstHourLesson { firstHour[0] }

    static var lessons: [FirstHourLesson] { firstHour }

    static var all: [FirstHourLesson] { firstHour + challenges }

    static func lesson(id: String) -> FirstHourLesson? {
        all.first { $0.id == id }
    }

    static func lesson(relativePath: String) -> FirstHourLesson? {
        all.first { $0.relativePath == relativePath }
    }

    static func index(of lesson: FirstHourLesson) -> Int? {
        switch lesson.track {
        case .firstHour: firstHour.firstIndex(where: { $0.id == lesson.id })
        case .challenge: challenges.firstIndex(where: { $0.id == lesson.id })
        }
    }

    static func next(after lesson: FirstHourLesson) -> FirstHourLesson? {
        switch lesson.track {
        case .firstHour:
            return firstHour.first { $0.number == lesson.number + 1 }
        case .challenge:
            return challenges.first { $0.number == lesson.number + 1 }
        }
    }

    static func nextIncomplete(after id: String, completedIds: [String]) -> FirstHourLesson? {
        guard let current = lesson(id: id) else {
            return continueLesson(in: .firstHour, completedIds: completedIds, currentIndex: 0)
                ?? continueLesson(in: .challenge, completedIds: completedIds, currentIndex: 0)
        }
        if let next = next(after: current), !completedIds.contains(next.id) {
            return next
        }
        if let unfinished = continueLesson(in: current.track, completedIds: completedIds, currentIndex: 0) {
            return unfinished
        }
        if current.track == .firstHour {
            return continueLesson(in: .challenge, completedIds: completedIds, currentIndex: 0)
        }
        return nil
    }

    static func continueLesson(in track: LessonTrack, completedIds: [String], currentIndex _: Int) -> FirstHourLesson? {
        let list = track == .firstHour ? firstHour : challenges
        if let unfinished = list.first(where: { !completedIds.contains($0.id) }) {
            return unfinished
        }
        return nil
    }

    static func isCurriculumFolder(_ folder: String) -> Bool {
        folder == "lessons" || folder == "challenges"
    }

    static let firstHour: [FirstHourLesson] = [
        FirstHourLesson(
            id: "hello",
            track: .firstHour,
            number: 1,
            title: "Hello",
            goal: "Print hello from lilC. Replace ??? in printf, then press RUN.",
            fileName: "01-hello.c",
            printHint: "hello from lilC",
            requireSource: [],
            requireAnySource: [],
            win: .contains("hello from lilC", ignoreCase: true),
            source: """
            #include <stdio.h>

            /* Lesson 1 of 20 — Hello.
               TODO: print hello from lilC */

            int main(void) {
                printf("???\\n");
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                printf("hello from lilC\\n");
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "variables",
            track: .firstHour,
            number: 2,
            title: "Variables",
            goal: "A variable holds a number. Replace ??? with a year, then RUN.",
            fileName: "02-variables.c",
            printHint: "year =",
            requireSource: [],
            requireAnySource: [],
            win: .contains("year =", ignoreCase: true),
            source: """
            #include <stdio.h>

            /* Lesson 2 of 20 — Variables.
               TODO: store a year */

            int main(void) {
                int year = ???;
                printf("year = %d\\n", year);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int year = 2026;
                printf("year = %d\\n", year);
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "if",
            track: .firstHour,
            number: 3,
            title: "If",
            goal: "C can choose. Fill in the condition so 28 prints warm.",
            fileName: "03-if.c",
            printHint: "warm",
            requireSource: ["if"],
            requireAnySource: [],
            win: .anyContains(["warm", "cool"], ignoreCase: true),
            source: """
            #include <stdio.h>

            /* Lesson 3 of 20 — If.
               TODO: print warm when temp is 20 or more */

            int main(void) {
                int temp = 28;
                if (???) {
                    printf("warm\\n");
                } else {
                    printf("cool\\n");
                }
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int temp = 28;
                if (temp >= 20) {
                    printf("warm\\n");
                } else {
                    printf("cool\\n");
                }
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "loop",
            track: .firstHour,
            number: 4,
            title: "Loop",
            goal: "Loops repeat work. Fill in the bound so the program prints 1 through 5.",
            fileName: "04-loop.c",
            printHint: "1 through 5",
            requireSource: [],
            requireAnySource: ["for", "while"],
            win: .contains("1\n2\n3", ignoreCase: false),
            source: """
            #include <stdio.h>

            /* Lesson 4 of 20 — Loop.
               TODO: print 1 through 5 */

            int main(void) {
                int n;
                for (n = 1; n <= ???; n = n + 1) {
                    printf("%d\\n", n);
                }
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int n;
                for (n = 1; n <= 5; n = n + 1) {
                    printf("%d\\n", n);
                }
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "array",
            track: .firstHour,
            number: 5,
            title: "Array",
            goal: "An array is a list. Add the values so the program prints 20.",
            fileName: "05-array.c",
            printHint: "20",
            requireSource: [],
            requireAnySource: ["for", "while"],
            win: .exact("20"),
            source: """
            #include <stdio.h>

            /* Lesson 5 of 20 — Array.
               TODO: add nums[i] into sum */

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
                    sum = ???;
                }
                printf("%d\\n", sum);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

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

            """
        ),
        FirstHourLesson(
            id: "function",
            track: .firstHour,
            number: 6,
            title: "Function",
            goal: "A function names a calculation. Make twice return n times 2.",
            fileName: "06-function.c",
            printHint: "42",
            requireSource: ["twice"],
            requireAnySource: [],
            win: .exact("42"),
            source: """
            #include <stdio.h>

            /* Lesson 6 of 20 — Function.
               TODO: return n times 2 */

            int twice(int n) {
                return ???;
            }

            int main(void) {
                printf("%d\\n", twice(21));
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int twice(int n) {
                return n * 2;
            }

            int main(void) {
                printf("%d\\n", twice(21));
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "add",
            track: .firstHour,
            number: 7,
            title: "Add",
            goal: "C can do math. Add 5 to n so the program prints 15.",
            fileName: "07-add.c",
            printHint: "15",
            requireSource: [],
            requireAnySource: ["+", "n"],
            win: .exact("15"),
            source: """
            #include <stdio.h>

            /* Lesson 7 of 20 — Add.
               TODO: add 5 to n */

            int main(void) {
                int n;
                n = 10;
                printf("%d\\n", n + ???);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int n;
                n = 10;
                printf("%d\\n", n + 5);
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "equals",
            track: .firstHour,
            number: 8,
            title: "Equals",
            goal: "Use == to compare. Fill in 4 so the program prints match.",
            fileName: "08-equals.c",
            printHint: "match",
            requireSource: ["=="],
            requireAnySource: [],
            win: .contains("match", ignoreCase: true),
            source: """
            #include <stdio.h>

            /* Lesson 8 of 20 — Equals.
               TODO: compare n to 4 */

            int main(void) {
                int n;
                n = 4;
                if (n == ???) {
                    printf("match\\n");
                } else {
                    printf("no\\n");
                }
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int n;
                n = 4;
                if (n == 4) {
                    printf("match\\n");
                } else {
                    printf("no\\n");
                }
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "while-loop",
            track: .firstHour,
            number: 9,
            title: "While",
            goal: "A while loop repeats while a test is true. Count down 3, 2, 1.",
            fileName: "09-while.c",
            printHint: "3 then 2 then 1",
            requireSource: [],
            requireAnySource: ["while"],
            win: .contains("3\n2\n1", ignoreCase: false),
            source: """
            #include <stdio.h>

            /* Lesson 9 of 20 — While.
               TODO: subtract 1 from n each time */

            int main(void) {
                int n;
                n = 3;
                while (n > 0) {
                    printf("%d\\n", n);
                    n = n - ???;
                }
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int n;
                n = 3;
                while (n > 0) {
                    printf("%d\\n", n);
                    n = n - 1;
                }
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "remainder",
            track: .firstHour,
            number: 10,
            title: "Remainder",
            goal: "% is leftover after divide. Fill in 2 so 8 prints even.",
            fileName: "10-remainder.c",
            printHint: "even",
            requireSource: ["%"],
            requireAnySource: [],
            win: .contains("even", ignoreCase: true),
            source: """
            #include <stdio.h>

            /* Lesson 10 of 20 — Remainder.
               TODO: test even with n % 2 */

            int main(void) {
                int n;
                n = 8;
                if (n % ??? == 0) {
                    printf("even\\n");
                } else {
                    printf("odd\\n");
                }
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int n;
                n = 8;
                if (n % 2 == 0) {
                    printf("even\\n");
                } else {
                    printf("odd\\n");
                }
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "and",
            track: .firstHour,
            number: 11,
            title: "And",
            goal: "&& means both tests. Fill in 20 so 12 prints in.",
            fileName: "11-and.c",
            printHint: "in",
            requireSource: ["&&"],
            requireAnySource: [],
            win: .exact("in"),
            source: """
            #include <stdio.h>

            /* Lesson 11 of 20 — And.
               TODO: n is 10 or more and 20 or less */

            int main(void) {
                int n;
                n = 12;
                if (n >= 10 && n <= ???) {
                    printf("in\\n");
                } else {
                    printf("out\\n");
                }
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int n;
                n = 12;
                if (n >= 10 && n <= 20) {
                    printf("in\\n");
                } else {
                    printf("out\\n");
                }
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "index",
            track: .firstHour,
            number: 12,
            title: "Index",
            goal: "The first slot is 0. Print the value at index 1, which is 9.",
            fileName: "12-index.c",
            printHint: "9",
            requireSource: ["["],
            requireAnySource: [],
            win: .exact("9"),
            source: """
            #include <stdio.h>

            /* Lesson 12 of 20 — Index.
               TODO: read nums[1] */

            int main(void) {
                int nums[3];
                nums[0] = 4;
                nums[1] = 9;
                nums[2] = 1;
                printf("%d\\n", nums[???]);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int nums[3];
                nums[0] = 4;
                nums[1] = 9;
                nums[2] = 1;
                printf("%d\\n", nums[1]);
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "count",
            track: .firstHour,
            number: 13,
            title: "Count",
            goal: "Count how many values are greater than 4. The program should print 2.",
            fileName: "13-count.c",
            printHint: "2",
            requireSource: ["if"],
            requireAnySource: ["for", "while"],
            win: .exact("2"),
            source: """
            #include <stdio.h>

            /* Lesson 13 of 20 — Count.
               TODO: count values greater than 4 */

            int main(void) {
                int nums[4];
                int i;
                int count;
                nums[0] = 3;
                nums[1] = 8;
                nums[2] = 6;
                nums[3] = 2;
                count = 0;
                for (i = 0; i < 4; i = i + 1) {
                    if (nums[i] > ???) {
                        count = count + 1;
                    }
                }
                printf("%d\\n", count);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int nums[4];
                int i;
                int count;
                nums[0] = 3;
                nums[1] = 8;
                nums[2] = 6;
                nums[3] = 2;
                count = 0;
                for (i = 0; i < 4; i = i + 1) {
                    if (nums[i] > 4) {
                        count = count + 1;
                    }
                }
                printf("%d\\n", count);
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "biggest",
            track: .firstHour,
            number: 14,
            title: "Biggest",
            goal: "Walk the list and keep the largest value. Print 9.",
            fileName: "14-biggest.c",
            printHint: "9",
            requireSource: ["if"],
            requireAnySource: ["for", "while"],
            win: .exact("9"),
            source: """
            #include <stdio.h>

            /* Lesson 14 of 20 — Biggest.
               TODO: store nums[i] when it is larger */

            int main(void) {
                int nums[3];
                int i;
                int max;
                nums[0] = 3;
                nums[1] = 9;
                nums[2] = 4;
                max = nums[0];
                for (i = 1; i < 3; i = i + 1) {
                    if (nums[i] > max) {
                        max = ???;
                    }
                }
                printf("%d\\n", max);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int nums[3];
                int i;
                int max;
                nums[0] = 3;
                nums[1] = 9;
                nums[2] = 4;
                max = nums[0];
                for (i = 1; i < 3; i = i + 1) {
                    if (nums[i] > max) {
                        max = nums[i];
                    }
                }
                printf("%d\\n", max);
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "nested",
            track: .firstHour,
            number: 15,
            title: "Nested",
            goal: "A loop inside a loop. Fill in 2 so the program prints 11 12 21 22.",
            fileName: "15-nested.c",
            printHint: "11 then 12 then 21 then 22",
            requireSource: [],
            requireAnySource: ["for", "while"],
            win: .contains("11\n12\n21\n22", ignoreCase: false),
            source: """
            #include <stdio.h>

            /* Lesson 15 of 20 — Nested.
               TODO: inner loop runs twice */

            int main(void) {
                int i;
                int j;
                for (i = 1; i <= 2; i = i + 1) {
                    for (j = 1; j <= ???; j = j + 1) {
                        printf("%d%d\\n", i, j);
                    }
                }
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int i;
                int j;
                for (i = 1; i <= 2; i = i + 1) {
                    for (j = 1; j <= 2; j = j + 1) {
                        printf("%d%d\\n", i, j);
                    }
                }
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "swap",
            track: .firstHour,
            number: 16,
            title: "Swap",
            goal: "Trade two values using a spare. Print 2 then 1.",
            fileName: "16-swap.c",
            printHint: "2 1",
            requireSource: ["tmp"],
            requireAnySource: [],
            win: .exact("2 1"),
            source: """
            #include <stdio.h>

            /* Lesson 16 of 20 — Swap.
               TODO: save a in tmp */

            int main(void) {
                int a;
                int b;
                int tmp;
                a = 1;
                b = 2;
                tmp = ???;
                a = b;
                b = tmp;
                printf("%d %d\\n", a, b);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int a;
                int b;
                int tmp;
                a = 1;
                b = 2;
                tmp = a;
                a = b;
                b = tmp;
                printf("%d %d\\n", a, b);
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "sum-fn",
            track: .firstHour,
            number: 17,
            title: "Sum",
            goal: "A function can take two inputs. Make sum return a plus b.",
            fileName: "17-sum.c",
            printHint: "7",
            requireSource: ["sum"],
            requireAnySource: [],
            win: .exact("7"),
            source: """
            #include <stdio.h>

            /* Lesson 17 of 20 — Sum.
               TODO: return a plus b */

            int sum(int a, int b) {
                return ???;
            }

            int main(void) {
                printf("%d\\n", sum(3, 4));
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int sum(int a, int b) {
                return a + b;
            }

            int main(void) {
                printf("%d\\n", sum(3, 4));
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "opposite",
            track: .firstHour,
            number: 18,
            title: "Opposite",
            goal: "If n is negative, return the positive. opposite(-4) should print 4.",
            fileName: "18-opposite.c",
            printHint: "4",
            requireSource: ["opposite"],
            requireAnySource: ["if"],
            win: .exact("4"),
            source: """
            #include <stdio.h>

            /* Lesson 18 of 20 — Opposite.
               TODO: return -n when n is less than 0 */

            int opposite(int n) {
                if (n < 0) {
                    return ???;
                }
                return n;
            }

            int main(void) {
                printf("%d\\n", opposite(-4));
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int opposite(int n) {
                if (n < 0) {
                    return -n;
                }
                return n;
            }

            int main(void) {
                printf("%d\\n", opposite(-4));
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "find",
            track: .firstHour,
            number: 19,
            title: "Find",
            goal: "Search the list for 7. Print its index, 1.",
            fileName: "19-find.c",
            printHint: "1",
            requireSource: ["if"],
            requireAnySource: ["for", "while"],
            win: .exact("1"),
            source: """
            #include <stdio.h>

            /* Lesson 19 of 20 — Find.
               TODO: compare each value to 7 */

            int main(void) {
                int nums[4];
                int i;
                int found;
                nums[0] = 1;
                nums[1] = 7;
                nums[2] = 3;
                nums[3] = 9;
                found = -1;
                for (i = 0; i < 4; i = i + 1) {
                    if (nums[i] == ???) {
                        found = i;
                    }
                }
                printf("%d\\n", found);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int nums[4];
                int i;
                int found;
                nums[0] = 1;
                nums[1] = 7;
                nums[2] = 3;
                nums[3] = 9;
                found = -1;
                for (i = 0; i < 4; i = i + 1) {
                    if (nums[i] == 7) {
                        found = i;
                    }
                }
                printf("%d\\n", found);
                return 0;
            }

            """
        ),
        FirstHourLesson(
            id: "copy",
            track: .firstHour,
            number: 20,
            title: "Copy",
            goal: "Copy each value into a second list. Print 4 9 1.",
            fileName: "20-copy.c",
            printHint: "4 9 1",
            requireSource: [],
            requireAnySource: ["for", "while"],
            win: .exact("4 9 1"),
            source: """
            #include <stdio.h>

            /* Lesson 20 of 20 — Copy.
               TODO: copy a[i] into b[i] */

            int main(void) {
                int a[3];
                int b[3];
                int i;
                a[0] = 4;
                a[1] = 9;
                a[2] = 1;
                for (i = 0; i < 3; i = i + 1) {
                    b[i] = ???;
                }
                printf("%d %d %d\\n", b[0], b[1], b[2]);
                return 0;
            }

            """,
            solution: """
            #include <stdio.h>

            int main(void) {
                int a[3];
                int b[3];
                int i;
                a[0] = 4;
                a[1] = 9;
                a[2] = 1;
                for (i = 0; i < 3; i = i + 1) {
                    b[i] = a[i];
                }
                printf("%d %d %d\\n", b[0], b[1], b[2]);
                return 0;
            }

            """
        ),
    ]

    static let challenges: [FirstHourLesson] = [
        twoSum, reverseDigits, palindrome, maxInArray, factorial, fibonacci,
        fizzBuzz, plusOne, singleNumber, climbStairs, validParens, moveZeroes,
    ]
}

private extension FirstHourCurriculum {
    static let twoSum = FirstHourLesson(
        id: "two-sum",
        track: .challenge,
        number: 1,
        title: "Two Sum",
        goal: "Find two indexes whose values add to 9. Print them on one line, like 0 1.",
        fileName: "01-two-sum.c",
        printHint: "0 1",
        requireSource: [],
        requireAnySource: ["for"],
        win: .exact("0 1"),
        source: """
        #include <stdio.h>

        /* Challenge 1 — Two Sum.
           TODO: print two indexes that add to target */

        int main(void) {
            int nums[4];
            int target;
            int i;
            int j;
            nums[0] = 2;
            nums[1] = 7;
            nums[2] = 11;
            nums[3] = 15;
            target = 9;
            for (i = 0; i < 4; i = i + 1) {
                for (j = i + 1; j < 4; j = j + 1) {
                    if (???) {
                        printf("%d %d\\n", i, j);
                        return 0;
                    }
                }
            }
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int nums[4];
            int target;
            int i;
            int j;
            nums[0] = 2;
            nums[1] = 7;
            nums[2] = 11;
            nums[3] = 15;
            target = 9;
            for (i = 0; i < 4; i = i + 1) {
                for (j = i + 1; j < 4; j = j + 1) {
                    if (nums[i] + nums[j] == target) {
                        printf("%d %d\\n", i, j);
                        return 0;
                    }
                }
            }
            return 0;
        }

        """
    )

    static let reverseDigits = FirstHourLesson(
        id: "reverse-digits",
        track: .challenge,
        number: 2,
        title: "Reverse digits",
        goal: "Reverse 123 so the program prints 321. Fill in the loop.",
        fileName: "02-reverse-digits.c",
        printHint: "321",
        requireSource: [],
        requireAnySource: ["while", "for"],
        win: .exact("321\n"),
        source: """
        #include <stdio.h>

        /* Challenge 2 — Reverse digits.
           TODO: build the reverse of n */

        int main(void) {
            int n = 123;
            int rev = 0;
            while (n > 0) {
                rev = ???;
                n = n / 10;
            }
            printf("%d\\n", rev);
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int n = 123;
            int rev = 0;
            while (n > 0) {
                rev = rev * 10 + n % 10;
                n = n / 10;
            }
            printf("%d\\n", rev);
            return 0;
        }

        """
    )

    static let palindrome = FirstHourLesson(
        id: "palindrome",
        track: .challenge,
        number: 3,
        title: "Palindrome",
        goal: "121 reads the same forwards and back. Print yes if n is a palindrome.",
        fileName: "03-palindrome.c",
        printHint: "yes",
        requireSource: ["if"],
        requireAnySource: [],
        win: .exact("yes"),
        source: """
        #include <stdio.h>

        /* Challenge 3 — Palindrome number.
           TODO: compare n with its reverse */

        int main(void) {
            int n = 121;
            int original = n;
            int rev = 0;
            while (n > 0) {
                rev = rev * 10 + n % 10;
                n = n / 10;
            }
            if (???) {
                printf("yes\\n");
            } else {
                printf("no\\n");
            }
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int n = 121;
            int original = n;
            int rev = 0;
            while (n > 0) {
                rev = rev * 10 + n % 10;
                n = n / 10;
            }
            if (rev == original) {
                printf("yes\\n");
            } else {
                printf("no\\n");
            }
            return 0;
        }

        """
    )

    static let maxInArray = FirstHourLesson(
        id: "max",
        track: .challenge,
        number: 4,
        title: "Maximum",
        goal: "Walk the array and print the largest value, 9.",
        fileName: "04-max.c",
        printHint: "9",
        requireSource: [],
        requireAnySource: ["for", "while"],
        win: .exact("9\n"),
        source: """
        #include <stdio.h>

        /* Challenge 4 — Maximum.
           TODO: keep the biggest value in best */

        int main(void) {
            int nums[5];
            int i;
            int best;
            nums[0] = 3;
            nums[1] = 9;
            nums[2] = 1;
            nums[3] = 4;
            nums[4] = 7;
            best = nums[0];
            for (i = 1; i < 5; i = i + 1) {
                if (???) {
                    best = nums[i];
                }
            }
            printf("%d\\n", best);
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int nums[5];
            int i;
            int best;
            nums[0] = 3;
            nums[1] = 9;
            nums[2] = 1;
            nums[3] = 4;
            nums[4] = 7;
            best = nums[0];
            for (i = 1; i < 5; i = i + 1) {
                if (nums[i] > best) {
                    best = nums[i];
                }
            }
            printf("%d\\n", best);
            return 0;
        }

        """
    )

    static let factorial = FirstHourLesson(
        id: "factorial",
        track: .challenge,
        number: 5,
        title: "Factorial",
        goal: "Compute 5! so the program prints 120.",
        fileName: "05-factorial.c",
        printHint: "120",
        requireSource: [],
        requireAnySource: ["for", "while"],
        win: .exact("120\n"),
        source: """
        #include <stdio.h>

        /* Challenge 5 — Factorial.
           TODO: multiply into product */

        int main(void) {
            int n = 5;
            int i;
            int product = 1;
            for (i = 1; i <= n; i = i + 1) {
                product = ???;
            }
            printf("%d\\n", product);
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int n = 5;
            int i;
            int product = 1;
            for (i = 1; i <= n; i = i + 1) {
                product = product * i;
            }
            printf("%d\\n", product);
            return 0;
        }

        """
    )

    static let fibonacci = FirstHourLesson(
        id: "fibonacci",
        track: .challenge,
        number: 6,
        title: "Fibonacci",
        goal: "Print the 8th Fibonacci number, 21. F1 is 1, F2 is 1.",
        fileName: "06-fibonacci.c",
        printHint: "21",
        requireSource: [],
        requireAnySource: ["for", "while"],
        win: .exact("21\n"),
        source: """
        #include <stdio.h>

        /* Challenge 6 — Fibonacci.
           TODO: walk the sequence to n = 8 */

        int main(void) {
            int n = 8;
            int a = 1;
            int b = 1;
            int i;
            int next;
            if (n <= 2) {
                printf("1\\n");
                return 0;
            }
            for (i = 3; i <= n; i = i + 1) {
                next = ???;
                a = b;
                b = next;
            }
            printf("%d\\n", b);
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int n = 8;
            int a = 1;
            int b = 1;
            int i;
            int next;
            if (n <= 2) {
                printf("1\\n");
                return 0;
            }
            for (i = 3; i <= n; i = i + 1) {
                next = a + b;
                a = b;
                b = next;
            }
            printf("%d\\n", b);
            return 0;
        }

        """
    )

    static let fizzBuzz = FirstHourLesson(
        id: "fizzbuzz",
        track: .challenge,
        number: 7,
        title: "Fizz Buzz",
        goal: "For 1 through 15, print Fizz, Buzz, FizzBuzz, or the number. One per line.",
        fileName: "07-fizzbuzz.c",
        printHint: "1 then 2 then Fizz",
        requireSource: ["if"],
        requireAnySource: ["for", "while"],
        win: .lines([
            "1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz",
            "11", "Fizz", "13", "14", "FizzBuzz",
        ]),
        source: """
        #include <stdio.h>

        /* Challenge 7 — Fizz Buzz.
           TODO: multiples of 3 and 5 */

        int main(void) {
            int n;
            for (n = 1; n <= 15; n = n + 1) {
                if (???) {
                    printf("FizzBuzz\\n");
                } else if (n % 3 == 0) {
                    printf("Fizz\\n");
                } else if (n % 5 == 0) {
                    printf("Buzz\\n");
                } else {
                    printf("%d\\n", n);
                }
            }
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int n;
            for (n = 1; n <= 15; n = n + 1) {
                if (n % 15 == 0) {
                    printf("FizzBuzz\\n");
                } else if (n % 3 == 0) {
                    printf("Fizz\\n");
                } else if (n % 5 == 0) {
                    printf("Buzz\\n");
                } else {
                    printf("%d\\n", n);
                }
            }
            return 0;
        }

        """
    )

    static let plusOne = FirstHourLesson(
        id: "plus-one",
        track: .challenge,
        number: 8,
        title: "Plus one",
        goal: "The digits 1, 2, 3 are a number. Add one and print 1 2 4.",
        fileName: "08-plus-one.c",
        printHint: "1 2 4",
        requireSource: [],
        requireAnySource: ["for", "while"],
        win: .exact("1 2 4"),
        source: """
        #include <stdio.h>

        /* Challenge 8 — Plus one.
           TODO: add one to the last digit */

        int main(void) {
            int d[3];
            int i;
            d[0] = 1;
            d[1] = 2;
            d[2] = 3;
            d[2] = ???;
            for (i = 0; i < 3; i = i + 1) {
                if (i > 0) {
                    printf(" ");
                }
                printf("%d", d[i]);
            }
            printf("\\n");
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int d[3];
            int i;
            d[0] = 1;
            d[1] = 2;
            d[2] = 3;
            d[2] = d[2] + 1;
            for (i = 0; i < 3; i = i + 1) {
                if (i > 0) {
                    printf(" ");
                }
                printf("%d", d[i]);
            }
            printf("\\n");
            return 0;
        }

        """
    )

    static let singleNumber = FirstHourLesson(
        id: "single-number",
        track: .challenge,
        number: 9,
        title: "Single number",
        goal: "Every value appears twice except one. Print the unique value, 3.",
        fileName: "09-single-number.c",
        printHint: "3",
        requireSource: [],
        requireAnySource: ["for", "while"],
        win: .exact("3\n"),
        source: """
        #include <stdio.h>

        /* Challenge 9 — Single number.
           TODO: XOR every value into lone */

        int main(void) {
            int nums[5];
            int i;
            int lone = 0;
            nums[0] = 2;
            nums[1] = 3;
            nums[2] = 2;
            nums[3] = 4;
            nums[4] = 4;
            for (i = 0; i < 5; i = i + 1) {
                lone = ???;
            }
            printf("%d\\n", lone);
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int nums[5];
            int i;
            int lone = 0;
            nums[0] = 2;
            nums[1] = 3;
            nums[2] = 2;
            nums[3] = 4;
            nums[4] = 4;
            for (i = 0; i < 5; i = i + 1) {
                lone = lone ^ nums[i];
            }
            printf("%d\\n", lone);
            return 0;
        }

        """
    )

    static let climbStairs = FirstHourLesson(
        id: "climb-stairs",
        track: .challenge,
        number: 10,
        title: "Climb stairs",
        goal: "You can take 1 or 2 steps. How many ways to climb 4 stairs? Print 5.",
        fileName: "10-climb-stairs.c",
        printHint: "5",
        requireSource: [],
        requireAnySource: ["for", "while"],
        win: .exact("5\n"),
        source: """
        #include <stdio.h>

        /* Challenge 10 — Climb stairs.
           TODO: ways(n) = ways(n-1) + ways(n-2) */

        int main(void) {
            int n = 4;
            int a = 1;
            int b = 2;
            int i;
            int next;
            if (n <= 2) {
                printf("%d\\n", n);
                return 0;
            }
            for (i = 3; i <= n; i = i + 1) {
                next = ???;
                a = b;
                b = next;
            }
            printf("%d\\n", b);
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int n = 4;
            int a = 1;
            int b = 2;
            int i;
            int next;
            if (n <= 2) {
                printf("%d\\n", n);
                return 0;
            }
            for (i = 3; i <= n; i = i + 1) {
                next = a + b;
                a = b;
                b = next;
            }
            printf("%d\\n", b);
            return 0;
        }

        """
    )

    static let validParens = FirstHourLesson(
        id: "valid-parens",
        track: .challenge,
        number: 11,
        title: "Valid parens",
        goal: "Count ( and ). Print valid if they nest correctly for (()()).",
        fileName: "11-valid-parens.c",
        printHint: "valid",
        requireSource: ["if"],
        requireAnySource: ["for", "while"],
        win: .exact("valid"),
        source: """
        #include <stdio.h>

        /* Challenge 11 — Valid parentheses.
           TODO: track depth; never go negative */

        int main(void) {
            char s[7];
            int i;
            int depth = 0;
            s[0] = '(';
            s[1] = '(';
            s[2] = ')';
            s[3] = '(';
            s[4] = ')';
            s[5] = ')';
            s[6] = 0;
            for (i = 0; s[i] != 0; i = i + 1) {
                if (s[i] == '(') {
                    depth = depth + 1;
                } else {
                    depth = ???;
                    if (depth < 0) {
                        printf("invalid\\n");
                        return 0;
                    }
                }
            }
            if (depth == 0) {
                printf("valid\\n");
            } else {
                printf("invalid\\n");
            }
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            char s[7];
            int i;
            int depth = 0;
            s[0] = '(';
            s[1] = '(';
            s[2] = ')';
            s[3] = '(';
            s[4] = ')';
            s[5] = ')';
            s[6] = 0;
            for (i = 0; s[i] != 0; i = i + 1) {
                if (s[i] == '(') {
                    depth = depth + 1;
                } else {
                    depth = depth - 1;
                    if (depth < 0) {
                        printf("invalid\\n");
                        return 0;
                    }
                }
            }
            if (depth == 0) {
                printf("valid\\n");
            } else {
                printf("invalid\\n");
            }
            return 0;
        }

        """
    )

    static let moveZeroes = FirstHourLesson(
        id: "move-zeroes",
        track: .challenge,
        number: 12,
        title: "Move zeroes",
        goal: "Keep the order of non-zero values, then zeros. Print 1 3 12 0 0.",
        fileName: "12-move-zeroes.c",
        printHint: "1 3 12 0 0",
        requireSource: [],
        requireAnySource: ["for", "while"],
        win: .exact("1 3 12 0 0"),
        source: """
        #include <stdio.h>

        /* Challenge 12 — Move zeroes.
           TODO: compact non-zeros toward the front */

        int main(void) {
            int nums[5];
            int i;
            int write = 0;
            nums[0] = 0;
            nums[1] = 1;
            nums[2] = 0;
            nums[3] = 3;
            nums[4] = 12;
            for (i = 0; i < 5; i = i + 1) {
                if (nums[i] != 0) {
                    nums[write] = nums[i];
                    write = ???;
                }
            }
            while (write < 5) {
                nums[write] = 0;
                write = write + 1;
            }
            for (i = 0; i < 5; i = i + 1) {
                if (i > 0) {
                    printf(" ");
                }
                printf("%d", nums[i]);
            }
            printf("\\n");
            return 0;
        }

        """,
        solution: """
        #include <stdio.h>

        int main(void) {
            int nums[5];
            int i;
            int write = 0;
            nums[0] = 0;
            nums[1] = 1;
            nums[2] = 0;
            nums[3] = 3;
            nums[4] = 12;
            for (i = 0; i < 5; i = i + 1) {
                if (nums[i] != 0) {
                    nums[write] = nums[i];
                    write = write + 1;
                }
            }
            while (write < 5) {
                nums[write] = 0;
                write = write + 1;
            }
            for (i = 0; i < 5; i = i + 1) {
                if (i > 0) {
                    printf(" ");
                }
                printf("%d", nums[i]);
            }
            printf("\\n");
            return 0;
        }

        """
    )
}
