module oliveharvest::recycling {
    use iota::object::{Self as obj, UID};
    use iota::tx_context::{Self as ctx, TxContext};
    use iota::transfer::{Self as trans};
    use iota::event::{Self as evt};
    use iota::coin::{Self, TreasuryCap};
    use std::option;

    /// One-Time-Witness pour le module recycling
    public struct RECYCLING has drop {}

    // Constante pour les récompenses: 5 tokens pour 10 kg (0.5 token/kg)
    const REWARD_PER_10KG: u64 = 5;

    // Struct Waste - TON STRUCT ORIGINAL INCHANGÉ
    public struct Waste has key, store {
        id: obj::UID,
        creator: address,           
        creator_type: vector<u8>,   
        date: u64,
        weight: u64,
        waste_type: vector<u8>,
        note: vector<u8>,
        destination: address,
    }

    // Event pour enregistrer la création de déchets - AMÉLIORÉ avec reward
    public struct WasteRecorded has copy, drop {
        waste_id: address,
        creator: address,          
        creator_type: vector<u8>,   
        date: u64,
        weight: u64,
        waste_type: vector<u8>,
        note: vector<u8>,
        destination: address,
        eco_tokens_earned: u64,     // NOUVEAU: tokens gagnés
    }

    // NOUVEAU Event pour tracer les récompenses
    public struct EcoTokensEarned has copy, drop {
        user: address,
        amount: u64,
        waste_id: address,
        weight: u64,
        timestamp: u64,
    }

    // Event pour mise à jour de destination - TON EVENT ORIGINAL INCHANGÉ
    public struct DestinationUpdated has copy, drop {
        waste_id: address,
        creator: address,           
        creator_type: vector<u8>,   
        old_destination: address,
        new_destination: address,
        updated_at: u64,
    }

    // NOUVELLE FONCTION: Initialisation du token de récompense
    fun init(witness: RECYCLING, ctx: &mut ctx::TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            0, // Pas de décimales
            b"ECO",
            b"EcoToken", 
            b"Tokens de recompense pour recyclage olive - 5 tokens pour 10kg",
            option::none(),
            ctx
        );
        
        // Transférer la treasury au déployeur pour qu'il puisse distribuer les récompenses
        trans::public_transfer(treasury, ctx::sender(ctx));
        trans::public_freeze_object(metadata);
    }

    // TON FONCTION ORIGINALE INCHANGÉE
    public fun unpack_waste(waste: Waste): (
        obj::UID,
        address,
        vector<u8>,
        u64,
        u64,
        vector<u8>,
        vector<u8>,
        address,
    ) {
        let Waste {
            id,
            creator,
            creator_type,
            date,
            weight,
            waste_type,
            note,
            destination,
        } = waste;
        
        (id, creator, creator_type, date, weight, waste_type, note, destination)
    }

    //  Enregistrer déchets AVEC récompenses
    public entry fun record_waste_with_rewards(
        creator_type: vector<u8>,
        date: u64,
        weight: u64,
        waste_type: vector<u8>,
        note: vector<u8>,
        destination: address,
        treasury: &mut TreasuryCap<RECYCLING>,  // Pour minter les tokens
        ctx: &mut ctx::TxContext,
    ) {
        let creator = ctx::sender(ctx);
        let id = obj::new(ctx);
        let waste_id = obj::uid_to_address(&id);

        // Calculer les tokens: 5 tokens pour chaque 10kg
        let eco_tokens = calculate_reward(weight);

        let creator_type_copy = creator_type;
        let waste_type_copy = waste_type;
        let note_copy = note;

        let waste = Waste {
            id,
            creator,
            creator_type: creator_type_copy,
            date,
            weight,
            waste_type: waste_type_copy,
            note: note_copy,
            destination,
        };

        // Donner les tokens de récompense
        if (eco_tokens > 0) {
            let reward_coin = coin::mint(treasury, eco_tokens, ctx);
            trans::public_transfer(reward_coin, creator);
            
            // Event pour tracer la récompense
            evt::emit(EcoTokensEarned {
                user: creator,
                amount: eco_tokens,
                waste_id,
                weight,
                timestamp: ctx::epoch(ctx),
            });
        };

        // Event principal avec récompense
        evt::emit(WasteRecorded {
            waste_id,
            creator,
            creator_type: creator_type_copy,
            date,
            weight,
            waste_type: waste_type_copy,
            note: note_copy,
            destination,
            eco_tokens_earned: eco_tokens,
        });

        // Transfert du déchet
        trans::transfer(waste, destination);
    }

    // TON FONCTION ORIGINALE INCHANGÉE (sans récompenses)
    public entry fun record_waste(
        creator_type: vector<u8>,   
        date: u64,
        weight: u64,
        waste_type: vector<u8>,
        note: vector<u8>,
        destination: address,
        ctx: &mut ctx::TxContext,
    ) {
        let creator = ctx::sender(ctx);
        let id = obj::new(ctx);
        let waste_id = obj::uid_to_address(&id);

        let creator_type_copy = creator_type;
        let waste_type_copy = waste_type;
        let note_copy = note;

        let waste = Waste {
            id,
            creator,
            creator_type: creator_type_copy,
            date,
            weight,
            waste_type: waste_type_copy,
            note: note_copy,
            destination,
        };

        // Event sans récompense
        evt::emit(WasteRecorded {
            waste_id,
            creator,
            creator_type: creator_type_copy,
            date,
            weight,
            waste_type: waste_type_copy,
            note: note_copy,
            destination,
            eco_tokens_earned: 0,  // Pas de récompense
        });

        trans::transfer(waste, destination);
    }

    // TON FONCTION ORIGINALE INCHANGÉE
    public entry fun update_destination(
        waste: &mut Waste,
        new_destination: address,
        ctx: &mut ctx::TxContext,
    ) {
        let old_destination = waste.destination;
        let waste_id = obj::uid_to_address(&waste.id);
        waste.destination = new_destination;

        evt::emit(DestinationUpdated {
            waste_id,
            creator: waste.creator,
            creator_type: waste.creator_type,
            old_destination,
            new_destination,
            updated_at: ctx::epoch(ctx),
        });
    }

    // TOUTES TES FONCTIONS ORIGINALES INCHANGÉES

    public fun get_waste_info(waste: &Waste): (
        address, &vector<u8>, u64, u64, &vector<u8>, &vector<u8>, address
    ) {
        (
            waste.creator,
            &waste.creator_type,
            waste.date,
            waste.weight,
            &waste.waste_type,
            &waste.note,
            waste.destination
        )
    }

    public fun get_waste_id(waste: &Waste): address {
        obj::uid_to_address(&waste.id)
    }

    public fun is_creator_owner(waste: &Waste, creator_address: address): bool {
        waste.creator == creator_address
    }

    public fun get_creator_type(waste: &Waste): &vector<u8> {
        &waste.creator_type
    }

    public fun is_created_by_farmer(waste: &Waste): bool {
        waste.creator_type == b"farmer"
    }

    public fun is_created_by_recycler(waste: &Waste): bool {
        waste.creator_type == b"recycler"
    }

    // NOUVELLES FONCTIONS UTILITAIRES POUR LES RÉCOMPENSES

    /// Calculer la récompense: 5 tokens pour chaque 10kg
    public fun calculate_reward(weight_kg: u64): u64 {
        // Division entière: 10kg = 5 tokens, 20kg = 10 tokens, etc.
        (weight_kg / 10) * REWARD_PER_10KG
    }

    /// Preview de récompense pour l'interface
    public fun get_potential_reward(weight_kg: u64): u64 {
        calculate_reward(weight_kg)
    }

    /// Obtenir le taux de récompense actuel
    public fun get_reward_rate(): (u64, u64) {
        (REWARD_PER_10KG, 10) // 5 tokens pour 10 kg
    }



/// Fonction publique pour déclencher des récompenses
public entry fun record_waste_public_rewards(
    creator_type: vector<u8>,
    date: u64,
    weight: u64,
    waste_type: vector<u8>,
    note: vector<u8>,
    destination: address,
    ctx: &mut ctx::TxContext,
) {
    let creator = ctx::sender(ctx);
    let id = obj::new(ctx);
    let waste_id = obj::uid_to_address(&id);

    // Calculer les tokens
    let eco_tokens = calculate_reward(weight);

    let waste = Waste {
        id,
        creator,
        creator_type,
        date,
        weight,
        waste_type,
        note,
        destination,
    };

    // Émettre l'événement de récompense 
    if (eco_tokens > 0) {
        evt::emit(EcoTokensEarned {
            user: creator,
            amount: eco_tokens,
            waste_id,
            weight,
            timestamp: ctx::epoch(ctx),
        });
    };

    // Event principal
    evt::emit(WasteRecorded {
        waste_id,
        creator,
        creator_type,
        date,
        weight,
        waste_type,
        note,
        destination,
        eco_tokens_earned: eco_tokens,
    });

    trans::transfer(waste, destination);
}


}