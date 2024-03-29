#let indent = 2em
#let no-indent(body) = {
    set par(first-line-indent: 0em)
    [#body]
    set par(first-line-indent: indent)
}
#set text(lang: "ru")
#set page(numbering: "1")
#set par(
  first-line-indent: indent,
  justify: true,
)
#show par: set block(spacing: 0.65em)

= Сигналы в Linux
Никитин Богдан, M3236
= Введение

_Сигнал_ - это уведомление для процесса о том, что произошло событие. Сигналы иногда описываются как _программные прерывания_. Сигналы аналогичны аппаратным прерываниям в том смысле, что они прерывают нормальный ход выполнения программы, и в большинстве случаев невозможно точно предсказать, когда сигнал поступит.

Один процесс может (если у него есть подходящие разрешения) отправлять сигнал другому процессу. В этом случае сигналы могут использоваться в качестве техники синхронизации или даже как примитивной формы межпроцессного взаимодействия (IPC). Также возможно отправление процессом сигнала самому себе. Однако обычным источником многих сигналов, отправляемых процессу, является ядро. Среди типов событий, вызывающих генерацию ядром сигнала для процесса, могут быть следующие:

- Произошло аппаратное исключение, что означает, что аппаратное обеспечение зафиксировало неверное состояние и оповестила об этом ядро, которое в свою очередь отправило соответствующий сигнал затронутому процессу. Примерами аппаратного исключения могут быть выполнение ошибочной машинной инструкции, деление на 0 или обращение к недоступному участку памяти.

- Пользователь ввел один из специальных символов терминала, которые генерируют сигналы. К таким символам относятся символ _прерывания_ (обычно `Control-C`) и символ _приостановки_ (обычно `Control-Z`).

- Произошло программное событие. Например, появился ввод на файловом дескрипторе, изменен размер окна терминала, сработал таймер, превышено временное ограничение ЦП или завершился дочерний процесс.

Каждый сигнал определен как целое число. Фактические числа, используемые для каждого сигнала, различаются в различных реализациях, поэтому в программах используются соотвествующие константы с именами вида `SIGxxx`, определённые в `<signal.h>` (как и все функции, использующиеся при работе с сигналами). Например, когда пользователь вводит символ _прерывания_, сигнал `SIGINT` (номер сигнала 2) поступает в процесс.

Сигналы делятся на две большие категории. Первый набор составляют _традиционные_ или _стандартные_ сигналы, которые используются ядром для уведомления процессов о событиях. На Linux стандартные сигналы нумеруются от 1 до 31. Другой набор сигналов состоит из сигналов _реального времени_, которые будут описаны позже.

Передача сигнала в ядре делится на две фазы:

#no-indent[*Генерация сигнала*]

Ядро обновляет структуру данных процесса-получателя, чтобы отразить тот факт, что новый сигнал был отправлен.

#no-indent[*Доставка сигнала*]

Ядро заставляет процесс-получатель реагировать на сигнал, изменяя его состояние выполнения, начиная выполнение указанного обработчика сигнала или и того, и другого.

#v(1em)

= Ожидающие сигналы и маска сигналов

Сигнал может быть _заблокирован_, что означает, что он не будет доставлен, пока его позже не разблокируют. Между моментом его генерации и моментом доставки сигнала говорят, что сигнал в _состоянии ожидания_.

У каждого потока в процессе есть независимая маска сигналов, которая указывает набор сигналов, которые в данный момент заблокированы для потока. Поток может управлять своей маской сигналов, используя `pthread_sigmask`. В традиционном однопоточном приложении можно использовать `sigprocmask` для управления маской сигналов.

Дочерний процесс, созданный с помощью `fork`, наследует копию маски сигналов своего родителя; маска сигналов сохраняется при использовании `execve`.

Сигнал может быть сгенерирован (а значит и стать ожидающим) как для всего процесса (например, при отправке с помощью `kill`) так и для отдельного потока (например, некоторые сигналы, такие как `SIGSEGV` и `SIGFPE`, сгенерированные в следствии выполнения определённой инструкции процессора в самом потоке, или сигналы, направленные определённому потоку с помощью `pthread_kill`). Направленный процессу сигнал может быть доставлен в любой из потоков, у которых сигнал не заблокирован. Если имеется несколько таких потоков, то ядро выбирает произвольный поток, которой и доставит сигнал.

Поток может получить набор сигналов, которые в данный момент находятся в состоянии ожидания, используя вызов `sigpending`. Этот набор будет состоять из объединения набора ожидающих сигналов, направленных процессу, и набора ожидающих сигналов для вызвавшего потока.

Потомок, созданный с помощью `fork`, изначально имеет пустой набор ожидающих сигналов; набор ожидающих сигналов сохраняется при использовании `execve`.

= Диспозиция сигналов
Каждый сигнал имеет текущий _обработчик_, который определяет, что будет делать процесс при поступлении сигнала.

В таблицах далее есть столбец «Действие», в котором указан обработчик по умолчанию для каждого сигнала:

#no-indent[*Term*]

Процесс завершается (убивается).

#no-indent[*Ign*] 

Сигнал игнорируется.

#no-indent[*Core*]

Процесс завершается (убивается), и, если возможно, создается файл ядра, содержащий его контекст выполнения; этот файл может использоваться в целях отладки.

#no-indent[*Stop*] 

Процесс останавливается

#no-indent[*Cont*] 

Если процесс был остановлен, его выполнение возобновляется

#v(1em)

Процесс может изменить обработчик сигнала с помощью `sigaction` или `signal` (второй вызов менее портируемый на другие системы, поэтому рекомендуется использовать первый). Используя данные системные вызовы процесс может выбрать одно из следующих действий при получении сигнала: выполнить действие по умолчанию, игнорировать сигнал, поймать сигнал обработчиком сигнала — функцией, задаваемой программистом, которая автоматически вызывается при получении сигнала (по умолчанию обработчик сигнала использует обычный стек процесса. Возможно сделать так, чтобы обработчик сигнала использовал альтернативный стек; это делается с помощью `sigaltstack` и может быть полезно при обработке сигнала `SIGSEGV`, который возникает при нехватке свободного места в обычном стеке процесса).

Реакция на сигналы является атрибутом процесса: в многопоточном приложении реакция на определённый сигнал одинакова для всех потоков.

Потомок, созданный с помощью `fork`, наследует реакцию на сигналы от своего родителя. При `execve` реакция на сигналы устанавливается в значение по умолчанию; реакция на игнорируемые сигналы не изменяется.

= Отправка сигнала
Для отправки сигнала можно использовать следующие системные вызовы и библиотечные функции:
#no-indent[`raise`]
Посылает сигнал вызвавшему потоку.
#no-indent[`kill`]
Посылает сигнал указанному процессу, всем членам указанной группы процессов или всем процессам в системе.
#no-indent[`killpg`]
Посылает сигнал всем членам указанной группы процессов.
#no-indent[`pthread_kill`]
Посылает сигнал указанному потоку в том же процессе, что и вызывающий.
#no-indent[`tgkill`]
Посылает сигнал указанному потоку в указанном процессе (данный системный вызов используется в реализации `pthread_kill`).
#no-indent[`sigqueue`]
Посылает сигнал реального времени указанному процессу с сопроводительными данными.

= Ожидание сигнала для обработки
Следующие системные вызовы приостанавливают выполнение вызывающего процесса или нити до тех пор, пока не будет пойман сигнал (или необработанный сигнал не завершит процесс):
#no-indent[`pause`]
Приостанавливает выполнение до тех пор, пока не будет пойман любой сигнал.
#no-indent[`sigsuspend`]
Временно изменяет маску сигналов и приостанавливает выполнение до получения одного из незамаскированных сигналов.
= Синхронный приём сигнала
В отличие от асинхронного получения сигнала через обработчик, возможно синхронно получить сигнал, то есть блокировать выполнение до поступления сигнала в некоторой точке, в которой ядро вернёт информацию о сигнале вызывающему. Для этого существует два пути:
- С помощью `sigwaitinfo`, `sigtimedwait` и `sigwait`. Они приостанавливают выполнение до поступления одного из заданного набора сигналов. Каждый из этих вызовов возвращает информацию о полученном сигнале.
- С помощью `signalfd`. Данный вызов возвращает файловый дескриптор, который можно использовать для чтения информации о сигналах, доставляемых вызывающему. Каждое выполнение `read` с этим файловым дескриптором блокируется до тех пор, пока один из сигналов набора, указанного в вызове `signalfd`, не будет послан вызывающему. В возвращаемом `read` буфере содержится структура, описывающая сигнал.

= Исполнение обработчиков сигналов

Всякий раз, когда происходит переход из режима ядра в режим пользователя (например, при возврате из системного вызова или планировании выполнения потока на процессоре), ядро проверяет, есть ли ожидающий незаблокированный сигнал, для которого процесс установил обработчик сигнала. Если такой сигнал существует, выполняются следующие шаги:

+ Ядро выполняет необходимые подготовительные шаги для выполнения обработчика сигнала:

  + Сигнал удаляется из набора ожидающих сигналов.

  + Если обработчик сигнала был установлен вызовом `sigaction` с установленным флагом `SA_ONSTACK`, и поток определил альтернативный стек сигналов (с использованием `sigaltstack`), то этот стек устанавливается.

  + Различные части контекста, связанные с сигналом, сохраняются в специальном фрейме, созданном в стеке. Сохраненная информация включает в себя:

    - регистр счетчика программы (адрес следующей инструкции в основной программе, которая должна выполниться при возврате из обработчика сигнала);
    - архитектурно-специфичное состояние регистров, необходимое для возобновления прерванной программы;
    - текущую маску сигналов потока;
    - настройки альтернативного стека сигналов потока.
    (Если обработчик сигнала был установлен с использованием флага `SA_SIGINFO` в `sigaction`, то вышеуказанная информация доступна через объект `ucontext_t`, на который указывает третий аргумент обработчика сигнала.)
  + Любые сигналы, указанные в `act->sa_mask` при регистрации обработчика с использованием `sigprocmask`, добавляются в маску сигналов потока. Сигнал, который доставляется, также добавляется в маску сигналов, если при регистрации обработчика не указан флаг `SA_NODEFER`. Эти сигналы блокируются во время выполнения обработчика.

  Если рассматривать функции, вызываемые в ядре, то порядок выполнения следующий: Прямо перед возвращением в режим пользователя ядро выполняет функцию `do_signal()`, которая, в свою очередь, обрабатывает сигнал (вызывая функцию `handle_signal()`) и настраивает стек режима пользователя (вызывая функцию `setup_frame()` или `setup_rt_frame()`). 
+ Когда процесс снова переключается в режим пользователя, он начинает выполнение обработчика сигнала, потому что адрес начала обработчика был принудительно установлен в счетчик программы. 
+ Когда эта функция завершается, выполняется участок кода пространства пользователя, называемый _трамплин сигнала_, адрес которого был размещен на стеке режима пользователя функцией `setup_frame()` или `setup_rt_frame()`. 
+ Этот код вызывает системный вызов `sigreturn()` или `rt_sigreturn()`; соответствующие служебные процедуры копируют аппаратный контекст программы в стек режима ядра и восстанавливают стек режима пользователя в его исходное состояние (вызывая функцию `restore_sigcontext()`). После завершения системного вызова программа может таким образом продолжить свое выполнение.

#figure(
  image("assets/1.png"),
  caption: [Обработка сигнала],
)

Если обработчик сигнала не возвращает управление (например, управление передается из обработчика с использованием `siglongjmp` или обработчик выполняет новую программу с `execve`), то последний шаг не выполняется. В частности, в таких сценариях ответственность за восстановление состояния маски сигналов (с использованием `sigprocmask`) лежит на программисте. (стоит отметить, что `siglongjmp` восстанавливает маску сигналов в зависимости от значения `savesigs`, указанного в соответствующем вызове `sigsetjmp`)

С точки зрения ядра, выполнение кода обработчика сигнала точно такое же, как выполнение любого другого кода пространства пользователя. Другими словами, ядро не записывает никакой специальной информации о состоянии, указывающей, что поток в данный момент выполняет код обработчика сигнала. Все необходимые сведения о состоянии сохраняются в регистрах пространства пользователя и стеке пространства пользователя. Глубина, на которую могут быть вложены обработчики сигналов, ограничена только стеком пространства пользователя.

= Стандартные сигналы

Linux поддерживает следующие сигналы:

#table(
    columns: (auto, auto, auto),
[*Сигнал*], [*Действие*], [*Пояснение*],
[`SIGABRT`], [Core], [Сигнал аварийного завершения от `abort`],
[`SIGALRM`], [Term], [Таймерный сигнал от `alarm`],
[`SIGBUS`], [Core], [Ошибка шины (недопустимый доступ к памяти)],
[`SIGCHLD`], [Ign], [Дочерний процесс остановлен или завершен],
[`SIGCLD`], [Ign], [Синоним для `SIGCHLD`],
[`SIGCONT`], [Cont], [Продолжить, если остановлен],
[`SIGEMT`], [Term], [Ловушка эмулятора],
[`SIGFPE`], [Core], [Ошибочная арифметическая операция],
[`SIGHUP`], [Term], [Обнаружен отсоединенный терминал или завершение контролирующего процесса],
[`SIGILL`], [Core], [Недопустимая инструкция],
[`SIGINFO`], [], [Синоним для `SIGPWR`],
[`SIGINT`], [Term], [Прерывание с клавиатуры],
[`SIGIO`], [Term], [I/O теперь возможен],
[`SIGIOT`], [Core], [IOT-ловушка. Синоним для `SIGABRT`],
[`SIGKILL`], [Term], [Убийство процесса],
[`SIGLOST`], [Term], [Потеряна блокировка файла (неиспользуется)],
[`SIGPIPE`], [Term], [Сломанный конвеер (pipe): запись в конвеер без читателей],
[`SIGPOLL`], [Term], [Событие опроса; синоним для `SIGIO`],
[`SIGPROF`], [Term], [Истек срок действия таймера профилирования],
[`SIGPWR`], [Term], [Сбой питания],
[`SIGQUIT`], [Core], [Выход с клавиатуры],
[`SIGSEGV`], [Core], [Недопустимая ссылка на память],
[`SIGSTKFLT`], [Term], [Ошибка стека на сопроцессоре (неиспользуется)],
[`SIGSTOP`], [Stop], [Остановить процесс],
[`SIGTSTP`], [Stop], [Остановить, набрано на терминале],
[`SIGSYS`], [Core], [Неверный системный вызов],
[`SIGTERM`], [Term], [Сигнал завершения],
[`SIGTRAP`], [Core], [Ловушка трассировки/точки останова],
[`SIGTTIN`], [Stop], [Ввод с терминала для фонового процесса],
[`SIGTTOU`], [Stop], [Вывод на терминал для фонового процесса],
[`SIGUNUSED`], [Core], [Синоним для `SIGSYS`],
[`SIGURG`], [Ign], [На сокете появились доступные для чтения срочные данные],
[`SIGUSR1`], [Term], [Пользовательский сигнал 1],
[`SIGUSR2`], [Term], [Пользовательский сигнал 2],
[`SIGVTALRM`], [Term], [Виртуальные будильник],
[`SIGXCPU`], [Core], [Превышено время CPU],
[`SIGXFSZ`], [Core], [Превышен размер файла],
[`SIGWINCH`], [Ign], [Сигнал изменения размера окна]
)

Сигналы `SIGKILL` и `SIGSTOP` нельзя перехватывать, блокировать или игнорировать.

Сигналы `SIGBUS`, `SIGFPE`, `SIGILL` и `SIGSEGV` могут быть сгенерированы вследствие аппаратного исключения или, что реже, путем отправки через функцию `kill`. В случае аппаратного исключения поведение процесса неопределено, если выполняется возврат из обработчика сигнала или если он блокирует или игнорирует сигнал. Для этого есть следующие причины:
- _Возврат из обработчика сигнала_. Предположим, что некоторый машинный код генерирует один из перечисленных сигналов, следовательно, инициируется обработчик. При нормальном возврате из обработчика программа пытается возобновить выполнение с той точки, в которой она была прервана. Однако это и есть та самая инструкция, которая сгенерировала сигнал, следовательно, сигнал генерируется повторно. Последствием такого поведения обычно является то, что программа уходит в бесконечный цикл, вновь и вновь вызывая обработчик сигнала.
- _Игнорирование сигнала_. В игнорировании аппаратно генерируемого сигнала очень мало смысла, так как непонятно, каким образом программа должна продолжать выполнение в случае, например, арифметического исключения. При генерации одного из вышеперечисленных сигналов в результате аппаратного исключения Linux доставляет этот сигнал в программу, даже несмотря на инструкцию игнорировать такие сигналы.
- _Блокирование сигнала_. Как и в предыдущем случае, в блокировании сигнала очень мало смысла, так как непонятно, каким образом программа должна продолжать выполнение. В Linux 2.4 и более ранних версиях ядро просто игнорирует попытки заблокировать аппаратно генерируемый сигнал. Он доставляется в процесс в любом случае, а затем либо завершает процесс, либо перехватывается обработчиком, если таковой был установлен. Начиная с Linux 2.6, если сигнал заблокирован, то процесс всегда незамедлительно аварийно завершается этим сигналом, даже если для процесса установлен обработчик данного сигнала. (Причина такого кардинального изменения в Linux 2.6 по части обработки заблокированных аппаратно генерируемых сигналов в скрытых ошибках поведения Linux 2.4, которые могли приводить к полному зависанию распоточенных программ.)
Правильным способом работы с аппаратно генерируемыми сигналами является либо принятие их действия по умолчанию (завершение процесса), либо написание обработчиков, которые не выполняют нормальный возврат. Вместо выполнения нормального возврата обработчик может завершить выполнение вызовом функции `_exit()` иля завершения процесса либо вызовом функции `siglongjump` для гарантии того, что управление передается в некую точку программы, отличную от инструкции, вызвавшей генерацию сигнала.

= Очередность и семантика доставки стандартных сигналов

Если несколько стандартных сигналов ожидают выполнения для процесса, порядок, в котором они будут доставлены, не определен.

Стандартные сигналы не образуют очередь. Если несколько экземпляров стандартного сигнала генерируются в то время, когда этот сигнал заблокирован, то только один экземпляр сигнала помечается как ожидающий (и сигнал будет доставлен только один раз при его разблокировке). В случае, когда стандартный сигнал уже ожидается, структура `siginfo_t`, связанная с этим сигналом, не перезаписывается при поступлении последующих экземпляров того же сигнала. Таким образом, процесс получит информацию, связанную с первым экземпляром сигнала.

= Сигналы реального времени
Начиная с версии 2.2, Linux поддерживает сигналы реального времени. Диапазон поддерживаемых сигналов реального времени определяется макросами `SIGRTMIN` и `SIGRTMAX`. 
Ядро Linux поддерживает 33 таких сигнала, начиная с номера 32 до номера 64. Однако внутри реализации потоков POSIX в glibc используется два (для NPTL) или три (для LinuxThreads) сигнала реального времени, а значение `SIGRTMIN` корректируется должным образом (до 34 или 35). Так как диапазон доступных сигналов реального времени различается в зависимости от реализации потоков в glibc (и это может происходить во время выполнения при смене ядра и glibc), и, более того, так как диапазон сигналов реального времени различен в разных системах UNIX, то программы никогда не должны задавать сигналы реального времени по номерам, а вместо этого всегда должны записывать их в виде `SIGRTMIN+n` и выполнять проверку (во время выполнения), что `SIGRTMIN+n` не превышает `SIGRTMAX`.

В отличие от стандартных сигналов, сигналы реального времени не имеют предопределенного назначения: весь набор сигналов реального времени приложения могут использовать так, как им нужно.

Действием по умолчанию для необработанных сигналов реального времени является завершение процесса (*Term*).

Сигналы реального времени отличаются от обычных в следующем:

+ В очередь можно добавлять несколько экземпляров одного сигнала реального времени. В случае со стандартными сигналами, если доставляется несколько экземпляров сигнала, в то время как этот тип сигнала в данный момент заблокирован, то только один экземпляр будет добавлен в очередь.
+ Если сигнал отправляется с помощью `sigqueue`, то с сигналом может быть отправлено некоторое значение (целочисленное, либо указатель). Если принимающий процесс устанавливает обработчик для сигнала, используя флаг `SA_SIGINFO и `вызов `sigaction`, то он может получить это значение через поле `si_value` структуры `siginfo_t`, переданной обработчику в виде второго аргумента. Кроме этого, поля `si_pid` и `si_uid` данной структуры можно использовать для получения идентификатора процесса и реального идентификатора пользователя, отправившего сигнал.
+ Сигналы реального времени доставляются точно в порядке поступления. Несколько сигналов одного типа доставляются в порядке, определяемых их отправлением. Если процессу отправлено несколько разных сигналов реального времени, то порядок их доставки начинается с сигнала с наименьшим номером (то есть сигналы с наименьшим номером имеют наивысший приоритет). Порядок же для стандартных сигналов в такой ситуации не определён.
Если процессу передан и стандартный сигнал, и сигнал реального времени, то в Linux, как и во многих других реализациях, первым будет получен стандартный сигнал.

В ядрах до версии 2.6.7 включительно, Linux накладывает общесистемный лимит на количество сигналов режима реального времени в очереди для всех процессов. Этот лимит может быть получен и изменён (если есть права) через файл _/proc/sys/kernel/rtsig-max_. Текущее количество сигналов режима реального времени в очереди можно получить из файла _/proc/sys/kernel/rtsig-nr_. В Linux 2.6.8 данные интерфейсы _/proc_ были заменены на ограничение ресурса `RLIMIT_SIGPENDING`, которое устанавливает ограничение на очередь сигналов на каждого пользователя отдельно.

Для дополнительных сигналов или сигналов реального времени требуется расширение структуры набора сигналов (`sigset_t`) с 32 до 64 бит. В связи с этим, различные системные вызовы заменены на новые системные вызов, поддерживающие набор сигналов большего размера. Эти вызовы соотвествуют старым, но имеют префикс `rt_`.

= Сигналобезопасность

_Асинхронно-сигналобезопасная_ функция - это функция, которую можно безопасно вызывать из обработчика сигнала. Многие функции _не_ являются асинхронно-сигналобезопасными. В частности, не реентерабельные функции, как правило, небезопасны для вызова из обработчика сигнала.

Проблемы, которые делают функцию небезопасной, можно быстро понять, если рассмотреть реализацию библиотеки stdio, все функции которой не являются асинхронно-сигналобезопасными.

При выполнении буферизованного ввода-вывода в файле функции _stdio_ должны поддерживать статически выделенный буфер данных вместе с соответствующими счетчиками и индексами (или указателями), которые записывают объем данных и текущую позицию в буфере. Предположим, что основная программа находится посередине вызова функции _stdio_, такой как `printf`, где буфер и связанные переменные были частично обновлены. Если в этот момент программа прерывается обработчиком сигнала, который также вызывает `printf`, то второй вызов `printf` будет работать с несогласованными данными, что приведет к непредсказуемым результатам.

Чтобы избежать проблем с небезопасными функциями, существует два возможных варианта:

+ Убедиться, что (а) обработчик сигнала вызывает только асинхронно-сигналобезопасные функции, и (б) сам обработчик сигнала является реентерабельным относительно глобальных переменных в основной программе.
+ Заблокировать доставку сигнала в основной программе при вызове функций, которые являются небезопасными, или при работе с глобальными данными, которые также используются обработчиком сигнала.

В общем случае второй вариант сложен в программах любой сложности, поэтому обычно выбирается первый вариант.

В общем случае функция считается асинхронно-сигналобезопасной либо потому, что она реентерабельна, либо потому, что она атомарна относительно сигналов (т.е. ее выполнение не может быть прервано обработчиком сигнала).

Согласно POSIX.1-2004 (также называемом POSIX.1-2001 Technical Corrigendum 2) от реализации требуется гарантировать, что следующие функции можно безопасно вызывать из обработчика сигнала:
```c
_Exit()
_exit()
abort()
accept()
access()
aio_error()
aio_return()
aio_suspend()
alarm()
bind()
cfgetispeed()
cfgetospeed()
cfsetispeed()
cfsetospeed()
chdir()
chmod()
chown()
clock_gettime()
close()
connect()
creat()
dup()
dup2()
execle()
execve()
fchmod()
fchown()
fcntl()
fdatasync()
fork()
fpathconf()
fstat()
fsync()
ftruncate()
getegid()
geteuid()
getgid()
getgroups()
getpeername()
getpgrp()
getpid()
getppid()
getsockname()
getsockopt()
getuid()
kill()
link()
listen()
lseek()
lstat()
mkdir()
mkfifo()
open()
pathconf()
pause()
pipe()
poll()
posix_trace_event()
pselect()
raise()
read()
readlink()
recv()
recvfrom()
recvmsg()
rename()
rmdir()
select()
sem_post()
send()
sendmsg()
sendto()
setgid()
setpgid()
setsid()
setsockopt()
setuid()
shutdown()
sigaction()
sigaddset()
sigdelset()
sigemptyset()
sigfillset()
sigismember()
signal()
sigpause()
sigpending()
sigprocmask()
sigqueue()
sigset()
sigsuspend()
sleep()
sockatmark()
socket()
socketpair()
stat()
symlink()
sysconf()
tcdrain()
tcflow()
tcflush()
tcgetattr()
tcgetpgrp()
tcsendbreak()
tcsetattr()
tcsetpgrp()
time()
timer_getoverrun()
timer_gettime()
timer_settime()
times()
umask()
uname()
unlink()
utime()
wait()
waitpid()
write()
```
В POSIX.1-2008 из списка выше удалены функции `fpathconf()`, `pathconf()` и `sysconf()` и добавлены следующие:

```c
execl()
execv()
faccessat()
fchmodat()
fchownat()
fexecve()
fstatat()
futimens()
linkat()
mkdirat()
mkfifoat()
mknod()
mknodat()
openat()
readlinkat()
renameat()
symlinkat()
unlinkat()
utimensat()
utimes()
```
В POSIX.1-2008 Technical Corrigendum 1 (2013) добавлены следующие функции:

```c
fchdir()
pthread_kill()
pthread_self()
pthread_sigmask()
```

= Пример

Ниже приведён пример простой программы на языке C, обрабатывающей в цикле сигнал `SIGINT`.

#no-indent[#raw(read("assets/example1.c"), lang: "c")]

#bibliography("bib.yml", full: true)
