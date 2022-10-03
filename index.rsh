'reach 0.1'

const [isOutcome, E_WINS, DRAW, C_WINS] = makeEnum(3);

const winner = (handCarla,guestCarla,handEve,guestEve) =>{
    const total = handCarla + handEve

    return guestCarla == total? (guestEve == total? 1 : 2): (guestEve == total? 0 : 1);
}     
     
assert(winner(2,4,2,0)==C_WINS)
assert(winner(2,4,3,5)==E_WINS)
assert(winner(2,4,2,4)==DRAW)
assert(winner(3,6,3,6)==DRAW)
assert(winner(2,3,2,3)==DRAW)


forall(UInt, handCarla=>
    forall(UInt, handEve=>
        forall(UInt, guess =>
            assert(winner(handCarla,guess,handEve,guess) == DRAW))))

const Player = {
    ...hasRandom,
    getHand: Fun([],UInt),
    guestHand: Fun([],UInt),
    seeOutcome: Fun([UInt],Null),
    informTimeout: Fun([],Null),
}

export const main = Reach.App(() =>{
    const Carla = Participant('Carla',{
        // specify Carla's interact interface here
        ...Player,
        wager: UInt,
        deadline: UInt,
    })
    const Eve = Participant('Eve',{
        // specify Eve's interact interface here
        ...Player,
        acceptWager: Fun([UInt], Null),
    })
    init()

    const informTimeout = () =>{
        each([Carla,Eve],()=>{
            interact.informTimeout();
        })
    }
    // write program here
    Carla.only(() => {
        const amount = declassify(interact.wager);
        const deadline = declassify(interact.deadline);
    })
    Carla.publish(amount,deadline)
        .pay(amount)
    commit()


    Eve.only(() => {
        interact.acceptWager(amount);
    });
    Eve.pay(amount)
        .timeout(relativeTime(deadline), () => closeTo(Carla, informTimeout));

    //must be in consensus
    var [outcome, v2] = [DRAW,false];
    invariant(balance() == 2 * amount && isOutcome(outcome))
    while (outcome == DRAW) {
        //body of loop
        commit();

        Carla.only(() =>{
            const _handCarla = interact.getHand();
            const [_commitCarlaHand, _saltCarlaHand] = makeCommitment(interact,_handCarla);
            const commitCarlaHand = declassify(_commitCarlaHand);
            const _guestCarla = interact.guestHand();
            const [_commitCarlaGuest, _saltCarlaGuest] = makeCommitment(interact,_guestCarla);
            const commitCarlaGuest = declassify(_commitCarlaGuest);
        });
        Carla.publish(commitCarlaHand,commitCarlaGuest)
        .timeout(relativeTime(deadline), () => closeTo(Eve, informTimeout));
        commit();

        unknowable(Eve,Carla(_handCarla,_saltCarlaHand,_guestCarla,_saltCarlaGuest));
        Eve.only(() => {
            const handEve = declassify(interact.getHand());
            const guestEve = declassify(interact.guestHand());
        });
        Eve.publish(handEve,guestEve)
        .timeout(relativeTime(deadline), () => closeTo(Carla, informTimeout))
        commit();

        Carla.only(() => {
            const saltCarlaHand = declassify(_saltCarlaHand);
            const handCarla = declassify(_handCarla);
            const saltCarlaGuest = declassify(_saltCarlaGuest);
            const guestCarla = declassify(_guestCarla);
        });

        Carla.publish(saltCarlaHand, handCarla,saltCarlaGuest,guestCarla)
        .timeout(relativeTime(deadline), () => closeTo(Eve, informTimeout));
        
        checkCommitment(commitCarlaHand,saltCarlaHand,handCarla);
        checkCommitment(commitCarlaGuest,saltCarlaGuest,guestCarla);
        
        outcome = winner(handCarla,guestCarla,handEve,guestEve);

        continue;
    }
    
    assert(outcome == C_WINS || outcome == E_WINS);
    transfer(2 * amount).to(outcome == C_WINS ? Carla : Eve)
    commit()

    each([Carla, Eve], () => {
        interact.seeOutcome(outcome)
    })
})
