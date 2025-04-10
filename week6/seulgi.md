### Kafka 아키텍처 그려보기✏️✏️
![image](https://github.com/user-attachments/assets/9d4e5364-0492-40ed-8cab-4117bbeca650)


### 공부 내용 정리 +Kafka 논문
### Introduction

 Kafka는 분산형이며 확장 가능하고, 높은 처리량을 제공한다. 

Kafka는 메시징 시스템과 유사한 API를 제공하여 애플리케이션이 로그 이벤트를 실시간으로 소비할 수 있도록 한다.

실시간 데이터 수집 및 처리를 위한 로깅 + 메시징 분산 처리 시스템.

### Related Work

1. **TPS에 대한 낮은 우선순위 처리**
    
    많은 전통 시스템들이 Throughput을 주요 설계 제약조건으로 고려하지 않음.
    
    JMS는 생산자(producer)가 여러 메시지를 묶어(batch) 한 번에 전송할 수 있는 API를 제공하지 않는다.
    
    → 로그 데이터는 초당 수천~수십만 건씩 발생할 수 있는데, 이를 하나씩 개별적으로 네트워크 왕복 요청으로 처리한다면??
    
        너무 느리기 때문에 한 번에 여러 개의 메시지를 묶어서 보내는 것이 필수적이다.
    
2. **분산처리를 위한 지원 기능이 부족**
    
    기존 시스템들은 분산 처리를 잘 지원하지 못한다. 
    
    여러 대의 서버에 메시지를 파티셔닝해서 저장하는 기능이 제대로 갖춰져 있지 않다.
    
3. **대기열 큐 처리 성능 저하**
    
    마지막으로, 많은 메시징 시스템은 메시지가 거의 즉시 소비된다고 가정하기 때문에, 아직 소비되지 않은 메시지를 저장하는 큐의 크기가 작을 것으로 예상한다. 하지만 데이터 웨어하우스 같은 경우,(실시간 online X, offline O) 지속적인 실시간 처리 대신 일정 시간마다 대량의 데이터를 한꺼번에 불러오기 때문에 큐에 메시지가 쌓이는 경우가 많다. 이 경우 기존 시스템은 성능이 급격히 저하된다.
    

**log aggregator Systems**

- 대부분은 오프라인 로그 데이터 소비를 위한 용도로 설계되어 있음.
- 대부분 “푸시(push)” 모델 사용 → 브로커가 소비자에게 데이터를 직접 전달한다.
- 머신 여러대가 로그 수집하고, 특정 시간마다 HDFS같은 저장소에 적재하는 방식

      → Data Highway(YaHoo), Scrible(Facebook) 등

- **Cloudera의 Flume**은 Pipe & Sink 개념을 활용해 스트리밍 데이터 처리에 유연성 제공 + 분산 처리 지원

### Kafka 아키텍처

위와 같은 기존 메시징 시스템 한계 극복을 위해 LinkedIn에서 개발한 분산형 메시지 기반 로그 수집기 = **Kafka**

1. **용어 정리**
    - **Topic**: 메시지를 분류하는 단위. 예: 뉴스 로그, 클릭 로그 등.
    - **Producer**: 메시지를 생성해서 특정 Topic으로 전송하는 주체.
    - **Broker**: Kafka 서버. 메시지를 저장하고, Consumer가 가져갈 수 있도록 제공.
    - **Partition**: Topic을 나눈 단위. 하나의 Topic은 여러 개의 Partition으로 나뉘고, 각각은 서로 다른 Broker에 저장될 수 있음.
    - **Consumer**: 메시지를 가져가서 사용하는 쪽.
  
### 메시지 전송, 소비 흐름 이해
![image (27)](https://github.com/user-attachments/assets/aea3b8b6-f0e6-4ad7-86f0-7669026cef1e)

**(Producer) → [Broker] → (Consumer) 구조로 흐른다.**

1. **(Producer) → [Broker]**
    
    Producer가 메시지를 Broker로 전송하면, Broker는 메시지를 저장한다.
    
    이때 Broker들이 여러개의 Partition에 분산되어 저장이 된다.
    
    하나의 Producer는 여러개의 Broker에 메시지를 전송하고, 각 브로커들은 파티션을 나눠 데이터를 저장한다.
    
    ex) Producer 코드 예시
    
    ```python
    producer = new Producer(…); 
    message = new Message(“test message str”.getBytes()); 
    set = new MessageSet(message); 
    producer.send(“topic1”, set);
    ```
    
2. **[Broker] → (Consumer)**
    
    Consumer는 자신이 가져올 메시지의 Topic을 구독한다.
    
    구독하면 Kafka는 해당 Topic의 메시지를 여러 개의 서브스트림으로 나눠서 메시지를 순서대로 읽는다.
    
    Iterator 방식을 사용하는데, 이 iterator가 무한히 작동하면서 메시지가 없으면 대기하다가, 새로운 메시지가 오면 자동으로 처리한다.
    
    각 Consumer가 Topic을 구독한 뒤에, Partition에서 직접 메시지를 가져오기 때문에 병렬적인 소비가 가능하고 확장성이 뛰어나다.
    
    ex) Consumer 코드 예시
    
    ```python
    streams[] = Consumer.createMessageStreams(“topic1”, 1) 
    for (message : streams[0]) { 
      bytes = message.payload(); 
      // do something with the bytes  
    }
    ```
    

**⭐ 헷갈리는 부분 추가 정리**

**Q1.** 파티션이 브로커보다 작은 단위니까 파티션을 결정하기 전에 브로커를 결정해야하는거 아닌가?

**A1.**  Kafka는 브로커를 먼저 선택하는게 아니라, 파티션을 먼저 선택하고, 그 파티션의 리더가 속한 브로커를 알아내서 메시지를 보냄.

- Producer가 Topic의 이름을 알고있음.(→ Kafka 클러스터가 해당 Topic의 파티션 개수, 리더 브로커 위치 정보를 메타데이터로 줌.)
- Producer는 메시지를 어떤 Partition에 넣을지 결정함.
- 그 Partition의 리더가 위치한 브로커로만 메시지를 전송함.

### Efficiency on a Single Partition

Kafka가 단일 파티션에서 어떻게 효율성을 확보하는지에 대해 알아보자.

1. **단순한 스토리지 구조**
    
    Kafka에서 각 Topic의 Partition은 하나의 논리적 로그이고, 물리적으로는 이 로그가 여러 개의 세그먼트 파일로 나뉘어 저장된다. (1segment = 1GB정도)
    
    Producer가 메시지를 보내면, Broker는 해당 메시지를 마지막 세그먼트에 단순히 추가한다.
    
    flush는 즉시 하지 않고, 메시지를 일정 개수 이상 모으거나 일정 시간이 지나면 디스크에 기록한다. 그리고 flush가 완료된 메시지만 Consumer가 읽을 수 있다.
    
    **⚠️ segment는 partition의 하위 단위**
    
    하나의 파티션이 여러개의 세그먼트 파일로 나뉘어서 저장되는데, 파티션 로그를 일정 크기마다 segment 단위로 잘라서 저장한다.(partition이 책이라면, segment는 책의 하나의 챕터 정도??)
    
2. **Kafka log 구조**
   ![image (26)](https://github.com/user-attachments/assets/be254020-196d-4681-8abd-4a89b6479070)
**fig2**에서 msg-00000000000 → 이런게 하나의 offset이고, in-memory index에 메시지들의 오프셋들이 정렬된 리스트로 유지된다.(오프셋은 순차적으로 증가, 연속적이지는 X)

오른쪽은 segment files로 Kafka가 실제 메시지를 저장하는 물리적일 파일들이다.

→ 메시지를 append할 때마다 가장 마지막 세그먼트에 추가되고, 그 offset은 메모리에 등록된다.

→Consumer는 offest기준으로 데이터를 읽고, 다음 offset을 ㅣ억했다가 이후 요청 시 사용한다.

- **Consumer 읽기 방식**
    
    Consumer는 특정 partition을 순차적으로 읽기 때문에, offset=5000을 ack했다면 그 이전 메시지는 모두 수신했다는 뜻이다.
    
    내부적으로는 비동기 pull 요청으로 데이터 버퍼를 미리 받아놓는다.
    
    (요청할때는 시작offset과 최대 byte 수를 포함해서 요청)
    
    Broker는 메모리에 offset 리스트를 정렬된 형태로 저장하고, 이 리스트를 검색해서 요청된 offset이 포함된 segment file을 찾아서 데이터를 전송한다.
    
    Consumer는 받은 메시지 처리한 다음, 다음 offset 계산해서 다음 pull 요청을 보낸다.
    
    → Kafka 내부에서 따로 캐싱하지는 않고 OS 파일시스템 page cache 사용? 이게 뭐가더좋은거지??
    
- **Stateless Broker**
    
    Kafka의 브로커는 consumer가 어디까지 읽었는지 기억하지 않고, consumer가 스스로 offset을 관리하는데, 그래서 브로커는 누가 어떤 메시지를 다 읽었는지를 몰라서 안전하게 메시지를 지울 수 없다.
    
    → 따라서 Time-base SLA(메시지가 설정된 시간 이상 지나면 자동으로 삭제하는 방식) 방식으로 메시지를 관리한다.
    
    → 보통 default값이 7일이고, 대부분의 consumer는 하루 단위로 소비하므로 현실적으로 문제가 없다고 한다.
    
- **Consumer Rewind 기능**
    
    보통 Queue는 메시지 한번 소비하면 사라지지만, consumer는 임의의 과거 offset으로 다시 돌아가서 메시지를 재처리할 수 있다. 
    
    → 데이터 저장소에 쓰기 중 crash가 발생할 경우 마지막 저장된 offset부터 다시 시작이 가능하다.

### Distributed Coordination

Kafka는 브로커도, 컨슈머도 모두 **분산된 상태**에서 작동하고, 컨슈머 그룹과 파티션을 기반으로 메시지를 나눠 읽도록 설계됨. Zookeeper를 활용해 동기화하고, **중앙 마스터 없이도 각자 알아서 조율함.**

1. **Producer가 파티션에 메시지를 보내는 방식**
    
    Producer는 메시지를 보낼 때 두가지 방식 중 하나를 선택한다.
    
    1. 무작위 파티션 선정 방식(Random) → Round Robin 등
    2. 키 기반 파티션(Keyed) → 특정 키에 따라 해시로 파티션 선택
2. **Consumer가 작동하는 방식**
    
    같은 그룹에 속한 컨슈머들은 공동으로 메시지를 나눠 처리한다. 하나의 메시지는 하나의 그룹 내에서는 오직 하나의 컨슈머에게만 전달된다.
    
    다른 그룹간에는 같은 메시지를 독립적으로 소비할 수 있다. (하나의 토픽에 대해 여러 그룹이 복수 구독을 할 수 있다.)
    ex) 같은 Topic을 Group A와 Group B가 구독하면, Group A, B는 각자 전체 메시지를 다 받지만, Group A 안에서는 Consumer 간에 나눠 받음.
    
3. **병렬 처리 단위는 Partition**
    
    Kafka에서는 하나의파티션은 동시에 하나의 Consumer 만이 소비하도록 한다.
    
    즉, 하나의 파티션을 여러 컨슈머가 동시에 읽는것을 허용하지 않는다.
    
    → 만약에 동시에 읽으면 lock, status 관리가 필요해서 복잡해지기 떄문에.
    
    대신 Kafka는 파티션을 더 많이 만들어서 부하를 나눠 처리하도록 유도한다.
    
    ex) Group A에 Consumer 2명 & Partition 6개 있으면
    
      → 한 Consumer가 3개씩 맡아서 처리. 
    
4. **중앙 마스터 없음**
    
    Kafka는 중앙 통제하는 master node를 두지 않고, 대신 Zookeeper라는 분산 동기화 시스템을 활용한다. (→ 버전업되고나서는 Zookeeper 없이 운영 가능해짐)
    
    Zookeeper는 파일시스템처럼 동작하는 API를 제공하고,
    
    - 노드를 만들고, 삭제하고, 읽고, 쓰고
    - 감시(watcher) 등록 가능 → 값이 변경되면 알림 받음
    - ephemeral 노드 → 클라이언트가 죽으면 자동 삭제됨
    
    Consumer가 새로 들어오거나, 빠지거나, 브로커에 변화가 생기면 Watcher가 감지하고 리밸런싱을 시작한다. → 이 알고리즘 Kafka 논문 p4에 나와있음. 추후 더 자세히 정리해보려고 한다.)
