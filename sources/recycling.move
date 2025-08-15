module oliveharvest::recycling {
    use iota::object::{Self as obj, UID};
    use iota::tx_context::{Self as ctx, TxContext};
    use iota::transfer::{Self as trans};
    use iota::event::{Self as evt};

    // Struct Waste adaptée pour farmers et recyclers
    public struct Waste has key, store {
        id: obj::UID,
        creator: address,           // Remplacé farmer par creator
        creator_type: vector<u8>,   // "farmer" ou "recycler"
        date: u64,
        weight: u64,
        waste_type: vector<u8>,
        note: vector<u8>,
        destination: address,
    }

    // Event pour enregistrer la création de déchets
    public struct WasteRecorded has copy, drop {
        waste_id: address,
        creator: address,           // Remplacé farmer par creator
        creator_type: vector<u8>,   // Type de créateur
        date: u64,
        weight: u64,
        waste_type: vector<u8>,
        note: vector<u8>,
        destination: address,
    }

    // Event pour mise à jour de destination
    public struct DestinationUpdated has copy, drop {
        waste_id: address,
        creator: address,           // Remplacé farmer par creator
        creator_type: vector<u8>,   // Type de créateur
        old_destination: address,
        new_destination: address,
        updated_at: u64,
    }

    // ✅ Fonction à ajouter au module recycling pour permettre la destruction contrôlée
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

    // Entrée publique pour enregistrer les déchets (farmers et recyclers)
    public entry fun record_waste(
        creator_type: vector<u8>,   // "farmer" ou "recycler"
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

        // Émettre l'event avant transfert
        evt::emit(WasteRecorded {
            waste_id,
            creator,
            creator_type: creator_type_copy,
            date,
            weight,
            waste_type: waste_type_copy,
            note: note_copy,
            destination,
        });

        // Transfert direct à la destination
        trans::transfer(waste, destination);
    }

    // Mise à jour de la destination avec émission d'un event
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

    // Getter info déchets (adapté)
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

    // Obtenir l'adresse ID d'un déchet
    public fun get_waste_id(waste: &Waste): address {
        obj::uid_to_address(&waste.id)
    }

    // Vérifier si un créateur est propriétaire d'un déchet (adapté)
    public fun is_creator_owner(waste: &Waste, creator_address: address): bool {
        waste.creator == creator_address
    }

    // Vérifier le type de créateur
    public fun get_creator_type(waste: &Waste): &vector<u8> {
        &waste.creator_type
    }

    // Vérifier si c'est un farmer
    public fun is_created_by_farmer(waste: &Waste): bool {
        waste.creator_type == b"farmer"
    }

    // Vérifier si c'est un recycler
    public fun is_created_by_recycler(waste: &Waste): bool {
        waste.creator_type == b"recycler"
    }
}