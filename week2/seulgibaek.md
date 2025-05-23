### Apache Kafka 2주차 (chapter1~3장 개념 정리)

- Kafka는 이러한 메시징 시스템을 위한 플랫폼으로 설계됨. "분산 커밋 로그" 또는 "분산 스트리밍 플랫폼"으로 알려짐.
- Kafka은 메시지를 내구성 있게 저장하고, 순서대로 읽을 수 있게 하여 데이터 손실을 방지.

### 메시지와 배치

- Kafka에서의 데이터 단위는 메시지이며, 메시지는 바이트 배열 형태.
- 메시지는 배치 방식으로 처리될 수 있으며, 이는 속도와 효율성을 높이는 데 도움을 줌.

<aside>
👌🏻

afka에서 데이터의 기본 단위는 '메시지'. 메시지는 단순히 바이트 배열로 구성되며, 실제 데이터 포맷에 대한 특정 형식을 요구하지 않는다. 메시지는 또한 선택적으로 '키'라는 메타데이터를 가질 수 있으며 이 키는 일관된 해시를 생성하여 해당 메시지를 특정 파티션으로 라우팅하는 데 사용된다. 이는 데이터의 구조적 처리를 가능하게 하며, 여러 애플리케이션이 동일한 메시지를 생산하면서도 데이터의 일관성을 유지할 수 있게 한다.

</aside>

### 주제(Topics)와 파티션(Partitions)

- 메시지는 주제에 따라 분류되며, 각 주제는 여러 개의 파티션으로 나뉨.
- 파티션은 데이터의 레코드를 순서대로 기록하고 읽을 수 있게 함.

<aside>
👌🏻

Kafka는 주제를 통해 메시지를 분류한다. 각 주제는 여러 파티션으로 나뉘며, 이는 데이터가 순서대로 기록되는 단일 로그 역할을 한다. 이 데이터는 디스크에 내구성 있게 저장되며, 각 주제에 대해서는 사용자의 필요에 따라 서로 다른 보존 규칙이 적용될 수 있다. 이러한 내구성 있는 저장 방식 덕분에 소비자는 처리 속도가 느려지거나 트래픽이 급증할 때에도 데이터 손실 걱정 없이 메시지를 안전하게 보관할 수 있다

Kafka는 구조화된 데이터를 처리하기 위해 스키마와 직렬화 메커니즘을 활용한다. 이는 데이터의 버전 호환성을 보장하고, 무질서를 방지하여 메시지의 효율적인 관리를 가능하게 한다. 주로 Apache Avro와 같은 직렬화 프레임워크가 사용되어, 서로 다른 데이터 구조를 갖는 메시지 간의 호환성을 확보한다

</aside>

### 생산자(Producer)와 소비자(Consumer)

- 생산자가 메시지를 작성하고, 소비자가 메시지를 읽는 구조.
- Kafka는 기본 생산자와 소비자 API 외에 Kafka Connect 및 Kafka Streams와 같은 고급 클라이언트 API를 제공.

<aside>
👌🏻

Kafka의 또 다른 장점은 뛰어난 확장성과 높은 성능이다. 사용자들은 초기에는 단일 브로커로 시작할 수 있으며, 필요에 따라 클러스터를 확장하여 수십 또는 수백 개의 브로커로 발전할 수 있다. 이 과정에서 클러스터는 연속적으로 서비스가 가능하며, 단일 브로커의 실패 시에도 다른 브로커가 대신 서비스를 제공하여 가용성을 유지한다

</aside>

### 여러 클러스터

- Kafka 배포 환경에서는 여러 클러스터를 사용하는 것이 유리할 수 있음.
- 여러 데이터 센터 간 데이터 복제를 쉽게 해주는 도구인 MirrorMaker 존재.

**용도**

- 실시간 모니터링, 사용자 활동 추적, 메트릭 수집 등 다양한 용도로 사용될 수 있음.
- 변경 로그(changelog) 스트림을 통해 데이터베이스의 변경사항을 추적할 수 있음.

**개발 역사**

- LinkedIn에서 Jay Kreps, Neha Narkhede, Jun Rao가 주도적으로 개발함.
- 2010년 오픈 소스로 출시되었으며, 이후 Apache Software Foundation의 프로젝트로 승격됨.
- 본격적으로 상용화된것은 2014년에 Confluent라는 회사가 설립되어 Kafka의 지원 및 교육을 제공하면서부터임.


## 2장

### Apache Kafka 설치

- Apache Kafka를 설정하기 위해서는 Apache ZooKeeper와의 통합이 필요함.
- 이 장에서는 Kafka 배포를 위한 기본 구성 옵션, 하드웨어 선택, 그리고 여러 Kafka 브로커를 클러스터로 설정하는 방법을 다룸.

<aside>
👌🏻

Kafka 설치의 첫 단계는 환경 설정이다. Apache Kafka는 Java 애플리케이션으로, 여러 운영 체제에서 실행될 수 있으나, 일반적인 사용 환경으로는 Linux를 추천한다. 다른 운영 체제에 대한 설치 정보는 부록에서 제공된다. Kafka와 ZooKeeper를 설치하기 전에는 Java 환경을 수립해야 하며, OpenJDK 기반의 Java 구현체, 특히 최신 Java Development Kit (JDK) 8 또는 11을 사용하는 것이 좋다.

</aside>

### Java 설치

- Java는 Kafka와 ZooKeeper의 필수 구성 요소로, Java Development Kit (JDK)를 설치해야 함.
- 보안상의 이유로, 최신 패치 버전을 사용하는 것이 추천됨.


### ZooKeeper 설치

- ZooKeeper는 Kafka 클러스터의 메타데이터 및 소비자 클라이언트 정보를 저장하는 중앙 집중식 서비스임.
- ZooKeeper는 Kafka와 긴밀하게 협력하며, 클러스터의 설정 정보를 관리하고 분산 동기화에 도움을 준다.

</aside>


### 클러스터 사이즈 결정

- 클러스터 사이즈는 필요한 디스크 용량, CPU 및 네트워크 용량에 따라 결정됨.
- 최소 브로커 수는 필요한 데이터 저장 용량과 브로커당 용량을 기준으로 계산됨.

### 브로커 구성

- 여러 Kafka 브로커가 동일한 클러스터에 참여하기 위해서는 두 가지 주요 설정이 필요함.
- ZooKeeper 연결 설정(zookeeper.connect) 및 각 브로커의 고유한 ID(broker.id)가 필수 조건임.

---

## 3장

### Kafka 생산자(Producer) 동작 원리
- Kafka 생산자는 데이터를 Kafka 클러스터에 전송하는 클라이언트 애플리케이션임
- 생산자는 메시지를 어떤 토픽과 파티션으로 보낼지 결정하고 오류 처리 메커니즘을 갖고 있음
- 전체 흐름은 메시지 생성부터 브로커 저장까지 여러 단계로 구성됨


<aside>
👌🏻

Kafka 생산자는 애플리케이션이 생성한 데이터를 Kafka 클러스터로 안정적으로 전송하는 핵심 컴포넌트. 생산자는 데이터를 어떤 토픽으로 보낼지, 어떻게 메시지를 직렬화할지, 오류가 발생했을 때 어떻게 처리할지 등을 결정합니다. 생산자의 주요 목표는 데이터를 토픽의 적절한 파티션에 정확하게 전달하고, 오류 상황에서도 데이터 손실 없이 안정적인 전송을 보장하는 것입니다.

</aside>



### ProducerRecord 구조
- 생산자가 보내는 데이터의 기본 단위는 ProducerRecord임
- ProducerRecord는 토픽, 파티션(선택적), 키(선택적), 값(실제 데이터)으로 구성됨
- 파티션과 키는 선택적이지만, 메시지 라우팅과 순서 보장에 중요한 역할을 함

<img width="479" alt="kafka_blueprint" src="https://github.com/user-attachments/assets/bfeda892-38be-407f-bc0f-099b0a1bf00f" />

<aside>
👌🏻

모든 Kafka 데이터 전송은 ProducerRecord 객체로 시작된다. 이 객체에는 데이터가 전송될 토픽 이름이 반드시 포함되어야 한다. 파티션은 선택적으로 지정할 수 있으며, 지정하지 않으면 파티셔너에 의해 자동으로 결정된다. 키(Key)는 메시지와 함께 전송되는 메타데이터로, 같은 키를 가진 메시지는 항상 같은 파티션으로 전송되어 순서가 보장된다. 값(Value)은 전송하고자 하는 실제 데이터 페이로드. 키와 값은 모두 직렬화되어 바이트 배열로 변환된 후 전송된다.

</aside>

### 전송 프로세스

- send() 메서드 호출로 시작되며, 직렬화 → 파티셔닝 → 배치 처리 → 브로커 전송 순으로 진행됨
- 메시지는 비동기적으로 처리되며, 추후 결과를 확인할 수 있는 Future 객체를 반환함
- 성공 시 메타데이터(토픽, 파티션, 오프셋 정보)를 반환하고, 실패 시 예외를 발생시킴

<aside>
👌🏻

생산자가 send() 메서드를 호출하면 메시지 전송 프로세스가 시작된다. 먼저 직렬화기(Serializer)는 키와 값을 바이트 배열로 변환한다. Kafka는 다양한 기본 직렬화기(String, Integer 등)를 제공하며, 필요에 따라 사용자 정의 직렬화기를 구현할 수도 있다. 아니면 그냥 제공해주는걸 쓴다.  **직렬화된** 메시지는 **파티셔너**(Partitioner)로 전달되어 어떤 파티션으로 보낼지 결정된다. 파티션이 명시적으로 지정되지 않았다면, **키의 해시값을 기반으로 파티션이 결정**되거나 키가 없는 경우 라운드 로빈 방식(→ 이게 뭐였더라)으로 파티션이 선택된다. 이렇게 **파티션**이 결정된 메시지는 해당 토픽-파티션에 대한 **배치(Batch)에 추가되어 Kafka 브로커로 전송**된다.

</aside>

### 배치 처리

- 생산자는 메시지를 개별적으로 바로 전송하지 않고 배치(Batch)로 모아서 한번에 전송함
- 각 토픽-파티션 조합마다 별도의 배치가 생성되고 관리됨
- 배치 처리는 네트워크 요청 수를 줄이고 처리량을 높여 전체 시스템 효율성을 향상시킴

<aside>
👌🏻

Kafka 생산자는 메시지를 즉시 브로커로 전송하지 않고, 같은 토픽과 파티션으로 향하는 메시지들을 배치로 모아서 전송한다. 그림에서 볼 수 있듯이, Topic A의 Partition 0과 Topic B의 Partition 1에 각각 Batch 0, Batch 1, Batch 2가 존재합니다. 이 배치 처리 방식은 네트워크 요청 횟수를 줄이고 처리량을 높여 시스템 전체의 효율성을 크게 향상시킨다. 배치가 언제 전송될지는 생산자 설정에 따라 달라지며, 일반적으로 배치 크기(batch.size)가 채워지거나, 일정 시간([linger.ms](http://linger.ms/))이 경과하면 전송된다.

</aside>

### 오류 처리 및 재시도 메커니즘

- 메시지 전송 중 오류가 발생하면 생산자는 재시도 여부를 결정함
- 재시도 가능한 오류(일시적 네트워크 문제 등)는 설정된 횟수만큼 자동으로 재시도함
- 재시도 불가능한 오류나 최대 재시도 횟수를 초과하면 예외를 발생시킴

<aside>
👌🏻

Kafka 생산자는 강력한 오류 처리 메커니즘을 갖추고 있다. 메시지 전송 중 문제가 발생하면, 생산자는 먼저 오류 유형을 평가한다. 그림에서 "Fail?" 판단 포인트에서 이 과정이 이루어진다. 재시도 가능한 오류(예: 일시적인 네트워크 장애, 브로커 장애)가 발생하면 "Retry?" 단계로 이동하여 재시도를 결정한다. Kafka 생산자는 retries 설정에 따라 자동으로 메시지 전송을 재시도하며, 재시도 간의 간격도 설정할 수 있다([retry.backoff.ms](http://retry.backoff.ms/)). 최대 재시도 횟수를 초과하거나, 메시지 크기 초과와 같은 재시도 불가능한 오류가 발생하면 생산자는 예외를 발생시킨다. 이러한 예외는 비동기 콜백을 통해 처리하거나, Future.get() 메서드를 호출하여 동기식으로 확인할 수 있다.

</aside>

### Kafka 브로커와의 상호작용

- 생산자는 클러스터의 모든 브로커와 통신할 수 있으며, 특히 토픽 파티션의 리더 브로커와 직접 통신함
- 브로커로부터 메타데이터를 주기적으로 업데이트하여 클러스터 변경사항을 반영함
- 생산자는 브로커로부터 전송 확인(ack)을 받아 전송 성공 여부를 판단함

<aside>
👌🏻

Kafka 생산자는 클러스터의 모든 브로커와 통신할 수 있지만, 메시지를 전송할 때는 해당 토픽 파티션의 리더 브로커에게만 직접 전송한다. 생산자는 클러스터 메타데이터를 주기적으로 업데이트하여 토픽, 파티션, 브로커 정보 등을 최신 상태로 유지한다. 메시지가 브로커에 성공적으로 전달되면, 설정된 acknowledgement 수준(acks)에 따라 브로커는 확인 응답을 보낸다. acks=0은 응답을 기다리지 않고, acks=1은 리더 브로커의 확인만 기다리며, acks=all은 모든 동기화 복제본까지 메시지가 복제되었는지 확인한다. 확인 응답을 받으면 생산자는 성공 메타데이터를 반환하고, 그렇지 않으면 오류 처리 및 재시도 메커니즘이 작동한다.

</aside>

### 생산자 구성 옵션

- 다양한 구성 옵션을 통해 생산자의 동작을 세밀하게 제어할 수 있음
- 주요 구성으로는 배치 크기, 지연 시간, 압축 방식, 재시도 횟수, 버퍼 메모리 등이 있음
- 애플리케이션의 요구사항에 맞게 지연 시간, 처리량, 신뢰성 간의 균형을 조절할 수 있음

<aside>
👌🏻

Kafka 생산자는 다양한 구성 옵션을 통해 세밀하게 제어할 수 있다. batch.size는 하나의 배치에 포함될 수 있는 최대 바이트 수를 지정하며, linger.ms는 배치가 전송되기 전에 대기하는 시간을 설정한다. buffer.memory는 브로커로 전송 대기 중인 메시지를 저장하는 버퍼의 크기를 지정한다. compression.type 설정으로 메시지 압축 방식(none, gzip, snappy, lz4, zstd)을 선택할 수 있으며, max.in.flight.requests.per.connection은 하나의 연결에서 동시에 처리될 수 있는 최대 요청 수를 제한한다. 이러한 설정들을 통해 개발자는 애플리케이션의 요구사항에 맞게 지연 시간, 처리량, 신뢰성 간의 균형을 조절할 수 있다.

</aside>

### 생산자 성능 최적화

- 메시지 배치 크기와 지연 시간을 조절하여 처리량과 지연 시간 간의 균형을 맞출 수 있음
- 압축을 활용하여 네트워크 대역폭 사용량을 줄이고 전체 처리량을 향상시킬 수 있음
- 버퍼 메모리와 요청 크기를 적절히 설정하여 메모리 사용량을 최적화할 수 있음

<aside>
👌🏻

Kafka 생산자의 성능을 최적화하기 위해서는 여러 설정을 적절히 조정해야 한다. 배치 크기(batch.size)를 늘리고 지연 시간([linger.ms](http://linger.ms/))을 증가시키면 처리량이 향상되지만 지연 시간이 길어질 수 있다. 반대로 이 값들을 줄이면 지연 시간은 감소하지만 처리량이 줄어들 수 있다. 메시지 압축(compression.type)을 활성화하면 네트워크 대역폭 사용량이 줄어들어 처리량이 향상될 수 있으나, CPU 사용량이 증가한다. 버퍼 메모리(buffer.memory)를 충분히 할당하고, max.request.size와 max.in.flight.requests.per.connection 값을 적절히 설정하여 생산자의 성능을 최적화할 수 있다. 대용량 메시지를 처리할 때는 특히 이러한 설정의 균형이 중요하다.

</aside>

### 일반적인 생산자 사용 사례

- 로그 수집: 애플리케이션 로그를 Kafka로 전송하여 중앙집중식 로그 처리 시스템 구축
- 이벤트 스트리밍: 실시간 이벤트 데이터를 다양한 시스템에 전달하는 이벤트 기반 아키텍처
- 데이터 통합: 다양한 소스의 데이터를 Kafka로 통합하여 일관된 데이터 파이프라인 구축
- 메트릭 수집: 시스템 및 애플리케이션 메트릭을 수집하여 모니터링 및 분석 시스템에 제공

<aside>
👌🏻

Kafka 생산자는 다양한 실제 사용 사례에서 활용된다. 로그 수집 시스템에서는 여러 애플리케이션의 로그를 Kafka로 전송하여 중앙에서 처리하고 분석한다. 이벤트 기반 아키텍처에서는 생산자가 사용자 활동, 시스템 이벤트 등을 실시간으로 Kafka에 게시하여 다양한 소비자 시스템에 전달힌다. 데이터 통합 시나리오에서는 여러 소스의 데이터를 Kafka로 통합하여 일관된 데이터 파이프라인을 구축한다. IoT 애플리케이션에서는 수많은
센서 데이터를 Kafka로 전송하여 실시간 처리 및 분석에 활용한다. 이러한 사용 사례에서 Kafka 생산자의 안정성, 확장성, 그리고 효율성은 전체 시스템의 성능과 안정성에 중요한 역할을 한다.

</aside>

### ProducerRecord와 메시지 키의 중요성

- 메시지 키는 데이터의 의미적 분류와 파티션 할당에 중요한 역할을 함
- 같은 키를 가진 메시지는 항상 같은 파티션으로 전송되어 순서가 보장됨
- 키가 없는 메시지는 라운드 로빈 방식으로 파티션에 분배됨

<aside>
👌🏻

Kafka 생산자에서 메시지 키(Key)의 선택은 전체 시스템 설계에 중요한 영향을 미친다. 키는 메시지의 의미적 식별자 역할을 하며, 파티션 할당을 결정하는 핵심 요소이다. 같은 키를 가진 모든 메시지는 항상 같은 파티션으로 전송되므로, 특정 엔티티나 이벤트와 관련된 메시지의 순서를 보장해야 할 때 중요하다. 예를 들어, 사용자 ID를 키로 사용하면 특정 사용자와 관련된 모든 이벤트가 순서대로 처리된다. 키가 없는 메시지는 라운드 로빈 방식으로 파티션에 분배되어 부하 분산은 되지만 순서는 보장되지 않는다. 키를 선택할 때는 데이터의 특성, 순서 보장 요구사항, 파티션 간 부하 분산 등을 종합적으로 고려해야 한다.

</aside>
