## Chapter 4. 카프카 컨슈머 

### 컨슈머 그룹
- 브로커는 성능을 위해 하나의 토픽을 여러 파티션으로 병렬 구성하여 처리합니다. 
- 하지만 둘 이상의 파티션을 하나의 컨슈머로만 처리한다면 성능 상의 문제가 발생할 수 있습니다. 
- 그래서 카프카 컨슈머는 하나 이상의 컨슈머가 컨슈머 그룹(Consumer Group)을 구성하여 하나의 토픽을 구독할 수 있습니다.

https://github.com/kyungjunleeme/kafka_study/discussions/6

https://www.youtube.com/watch?v=OxMdru93E6k&t=798s