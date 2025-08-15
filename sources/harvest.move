module oliveharvest::harvest {
    use iota::object::{Self as obj, UID};
    use iota::tx_context::{Self as ctx, TxContext};
    use iota::transfer::{Self as trans};
    use iota::event::{Self as evt};

    // Struct avec les bons types
    public struct Harvest has key, store {
        id: object::UID,
        farmer: address,
        date: u64,
        quantity: u64,
        olive_type: vector<u8>,
        method: vector<u8>,
        note: vector<u8>,  // Note optionnelle pour des détails supplémentaires
        destination: address,
    }

    // Event pour tracer les récoltes
    public struct HarvestRecorded has copy, drop {
        harvest_id: address,  // IOTA utilise address pour les IDs
        farmer: address,
        date: u64,
        quantity: u64,
        olive_type: vector<u8>,
        method: vector<u8>,
        note: vector<u8>,  // Note optionnelle
        destination: address,
    }

    // ✅ Event pour tracer les mises à jour de destination
    public struct DestinationUpdated has copy, drop {
        harvest_id: address,
        farmer: address,
        old_destination: address,
        new_destination: address,
        updated_at: u64,
    }

    // ✅ Fonction publique pour permettre la destruction contrôlée
    public fun unpack_harvest(harvest: Harvest): (
        object::UID,
        address,
        u64,
        u64,
        vector<u8>,
        vector<u8>,
        vector<u8>,
        address,
    ) {
        let Harvest {
            id,
            farmer,
            date,
            quantity,
            olive_type,
            method,
            note,
            destination,
        } = harvest;
        
        (id, farmer, date, quantity, olive_type, method, note, destination)
    }

    // ✅ Enregistrement + transfert à destination + émission d'event
    public entry fun record_harvest(
        date: u64,
        quantity: u64,
        olive_type: vector<u8>,
        method: vector<u8>,
        note: vector<u8>,  // Note optionnelle
        destination: address,
        ctx: &mut tx_context::TxContext,
    ) {
        let farmer = ctx::sender(ctx);
        let id = obj::new(ctx);
        let harvest_id = obj::uid_to_address(&id);

        // Copier les vecteurs pour l'événement
        let olive_type_copy = olive_type;
        let method_copy = method;
        let note_copy = note;

        let harvest = Harvest {
            id,
            farmer,
            date,
            quantity,
            olive_type: olive_type_copy,
            method: method_copy,
            note: note_copy,
            destination,
        };

        // ✅ Émission de l'événement AVANT le transfert
        evt::emit(HarvestRecorded {
            harvest_id,
            farmer,
            date,
            quantity,
            olive_type: olive_type_copy,
            method: method_copy,
            note: note_copy,
            destination,
        });

        // ✅ Transfert direct à l'usine
        trans::transfer(harvest, destination);
    }

    // ✅ Getter avec types à jour
    public fun get_harvest_info(harvest: &Harvest): (
        address, u64, u64, &vector<u8>, &vector<u8>, &vector<u8>, address
    ) {
        (
            harvest.farmer,
            harvest.date,
            harvest.quantity,
            &harvest.olive_type,
            &harvest.method,
            &harvest.note,
            harvest.destination
        )
    }

    // ✅ Mise à jour destination avec event
    public entry fun update_destination(
        harvest: &mut Harvest,
        new_destination: address,
        ctx: &mut tx_context::TxContext,
    ) {
        let old_destination = harvest.destination;
        let harvest_id = obj::uid_to_address(&harvest.id);
        harvest.destination = new_destination;

        // ✅ Émission de l'événement de mise à jour
        evt::emit(DestinationUpdated {
            harvest_id,
            farmer: harvest.farmer,
            old_destination,
            new_destination,
            updated_at: ctx::epoch(ctx),
        });
    }

    // ✅ Fonction utilitaire pour obtenir l'ID d'une récolte
    public fun get_harvest_id(harvest: &Harvest): address {
        obj::uid_to_address(&harvest.id)
    }

    // ✅ Fonction pour vérifier si un farmer est propriétaire d'une récolte
    public fun is_farmer_owner(harvest: &Harvest, farmer_address: address): bool {
        harvest.farmer == farmer_address
    }
}