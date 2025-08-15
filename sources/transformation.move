module oliveharvest::transformation {
    use iota::object::{Self as obj, UID};
    use iota::tx_context::{Self as ctx, TxContext};
    use iota::event::{Self as evt};
    use oliveharvest::recycling::{Self as recycling, Waste};

    // ✅ Struct pour le produit recyclé avec toutes les infos
    public struct RecycledProduct has key, store {
        id: object::UID,
        // Informations du déchet original
        original_creator: address,
        original_creator_type: vector<u8>,
        waste_date: u64,
        waste_weight: u64,
        original_waste_type: vector<u8>,
        waste_note: vector<u8>,
        // Informations de transformation
        recycling_facility: address,
        transformation_date: u64,
        transformation_method: vector<u8>,
        transformation_temperature: u64,
        transformation_note: vector<u8>,
        // Nouveau produit
        product_type: vector<u8>,        // Type de produit recyclé (plastique, papier, etc.)
        product_quantity: u64,           // Quantité produite
        product_quality_grade: vector<u8>, // Grade de qualité (A, B, C)
    }

    // ✅ Event pour tracer la transformation
    public struct WasteTransformed has copy, drop {
        product_id: address,
        waste_id: address,
        original_creator: address,
        original_creator_type: vector<u8>,
        recycling_facility: address,
        waste_date: u64,
        transformation_date: u64,
        waste_weight: u64,
        product_quantity: u64,
        original_waste_type: vector<u8>,
        product_type: vector<u8>,
        transformation_method: vector<u8>,
        transformation_temperature: u64,
        product_quality_grade: vector<u8>,
    }

    // ✅ Fonction de transformation qui consume le Waste et produit le RecycledProduct
    public entry fun transform_waste(
        waste: Waste,
        transformation_date: u64,
        transformation_method: vector<u8>,
        transformation_temperature: u64,
        transformation_note: vector<u8>,
        product_type: vector<u8>,
        product_quantity: u64,
        product_quality_grade: vector<u8>,
        ctx: &mut tx_context::TxContext,
    ) {
        let recycling_facility = ctx::sender(ctx);
        
        // Récupérer les infos du déchet avant de le consommer
        let waste_id = recycling::get_waste_id(&waste);
        let (
            original_creator,
            original_creator_type,
            waste_date,
            waste_weight,
            original_waste_type,
            waste_note,
            _destination
        ) = recycling::get_waste_info(&waste);

        // Copier les vecteurs
        let original_creator_type_copy = *original_creator_type;
        let original_waste_type_copy = *original_waste_type;
        let waste_note_copy = *waste_note;
        let transformation_method_copy = transformation_method;
        let transformation_note_copy = transformation_note;
        let product_type_copy = product_type;
        let product_quality_grade_copy = product_quality_grade;

        // Détruire le Waste (il est consumé) - Note: il faut ajouter une fonction unpack_waste au module recycling
        // Consume and destroy the Waste object
        let (id, _creator, _creator_type, _date, _weight, _waste_type, _note, _destination) = recycling::unpack_waste(waste);
        obj::delete(id);
        // Pour l'instant, on suppose que le waste est détruit automatiquement après consommation
        
        // Créer le produit recyclé
        let product_id = obj::new(ctx);
        let product_id_address = obj::uid_to_address(&product_id);

        let recycled_product = RecycledProduct {
            id: product_id,
            original_creator,
            original_creator_type: original_creator_type_copy,
            waste_date,
            waste_weight,
            original_waste_type: original_waste_type_copy,
            waste_note: waste_note_copy,
            recycling_facility,
            transformation_date,
            transformation_method: transformation_method_copy,
            transformation_temperature,
            transformation_note: transformation_note_copy,
            product_type: product_type_copy,
            product_quantity,
            product_quality_grade: product_quality_grade_copy,
        };

        // ✅ Émission de l'événement
        evt::emit(WasteTransformed {
            product_id: product_id_address,
            waste_id,
            original_creator,
            original_creator_type: original_creator_type_copy,
            recycling_facility,
            waste_date,
            transformation_date,
            waste_weight,
            product_quantity,
            original_waste_type: original_waste_type_copy,
            product_type: product_type_copy,
            transformation_method: transformation_method_copy,
            transformation_temperature,
            product_quality_grade: product_quality_grade_copy,
        });

        // Le produit recyclé reste dans l'usine de recyclage
        iota::transfer::transfer(recycled_product, recycling_facility);
    }

    // ✅ Fonction pour transformer plusieurs déchets en un seul produit (batch processing)
    public entry fun batch_transform_waste(
    mut wastes: vector<Waste>,  // Add 'mut' to make it mutable
    transformation_date: u64,
    transformation_method: vector<u8>,
    transformation_temperature: u64,
    transformation_note: vector<u8>,
    product_type: vector<u8>,
    product_quantity: u64,
    product_quality_grade: vector<u8>,
    ctx: &mut tx_context::TxContext,
) {
    let recycling_facility = ctx::sender(ctx);
    let mut total_weight = 0;  // Add 'mut' to make it mutable
    let batch_size = vector::length(&wastes);
    let mut i = 0;  // Add 'mut' to make it mutable

    // Calculate total weight
    while (i < batch_size) {
        let waste = vector::borrow(&wastes, i);
        let (_, _, _, weight, waste_type, _, _) = recycling::get_waste_info(waste);
        total_weight = total_weight + weight;
        i = i + 1;
    };

    // Create recycled product
    let product_id = obj::new(ctx);
    let product_id_address = obj::uid_to_address(&product_id);

    let recycled_product = RecycledProduct {
        id: product_id,
        original_creator: @0x0,
        original_creator_type: b"batch",
        waste_date: transformation_date,
        waste_weight: total_weight,
        original_waste_type: b"mixed",
        waste_note: b"batch_processing",
        recycling_facility,
        transformation_date,
        transformation_method,
        transformation_temperature,
        transformation_note,
        product_type,
        product_quantity,
        product_quality_grade,
    };

    // Emit event
    evt::emit(WasteTransformed {
        product_id: product_id_address,
        waste_id: @0x0,
        original_creator: @0x0,
        original_creator_type: b"batch",
        recycling_facility,
        waste_date: transformation_date,
        transformation_date,
        waste_weight: total_weight,
        product_quantity,
        original_waste_type: b"mixed",
        product_type,
        transformation_method,
        transformation_temperature,
        product_quality_grade,
    });

    // Properly destroy all waste objects
    while (!vector::is_empty(&mut wastes)) {
        let waste = vector::pop_back(&mut wastes);
        let (id, _, _, _, _, _, _, _) = recycling::unpack_waste(waste);
        obj::delete(id);
    };
    vector::destroy_empty(wastes);

    // Transfer the recycled product
    iota::transfer::transfer(recycled_product, recycling_facility);
}

    // ✅ Getter pour toutes les infos du produit recyclé
    public fun get_product_info(product: &RecycledProduct): (
        address,     // original_creator
        &vector<u8>, // original_creator_type
        u64,         // waste_date
        u64,         // waste_weight
        &vector<u8>, // original_waste_type
        &vector<u8>, // waste_note
        address,     // recycling_facility
        u64,         // transformation_date
        &vector<u8>, // transformation_method
        u64,         // transformation_temperature
        &vector<u8>, // transformation_note
        &vector<u8>, // product_type
        u64,         // product_quantity
        &vector<u8>, // product_quality_grade
    ) {
        (
            product.original_creator,
            &product.original_creator_type,
            product.waste_date,
            product.waste_weight,
            &product.original_waste_type,
            &product.waste_note,
            product.recycling_facility,
            product.transformation_date,
            &product.transformation_method,
            product.transformation_temperature,
            &product.transformation_note,
            &product.product_type,
            product.product_quantity,
            &product.product_quality_grade,
        )
    }

    // ✅ Getter pour l'ID du produit
    public fun get_product_id(product: &RecycledProduct): address {
        obj::uid_to_address(&product.id)
    }

    // ✅ Vérifier si une usine de recyclage est propriétaire
    public fun is_facility_owner(product: &RecycledProduct, facility_address: address): bool {
        product.recycling_facility == facility_address
    }

    // ✅ Getter pour les informations originales du déchet
    public fun get_original_waste_info(product: &RecycledProduct): (
        address,     // original_creator
        &vector<u8>, // original_creator_type
        u64,         // waste_date
        u64,         // waste_weight
        &vector<u8>, // original_waste_type
    ) {
        (
            product.original_creator,
            &product.original_creator_type,
            product.waste_date,
            product.waste_weight,
            &product.original_waste_type,
        )
    }

    // ✅ Getter pour les informations de transformation
    public fun get_transformation_info(product: &RecycledProduct): (
        address,     // recycling_facility
        u64,         // transformation_date
        &vector<u8>, // transformation_method
        u64,         // transformation_temperature
        &vector<u8>, // product_type
        u64,         // product_quantity
        &vector<u8>, // product_quality_grade
    ) {
        (
            product.recycling_facility,
            product.transformation_date,
            &product.transformation_method,
            product.transformation_temperature,
            &product.product_type,
            product.product_quantity,
            &product.product_quality_grade,
        )
    }

    // ✅ Fonction utilitaire pour vérifier le type de créateur original
    public fun is_originally_from_farmer(product: &RecycledProduct): bool {
        product.original_creator_type == b"farmer"
    }

    public fun is_originally_from_recycler(product: &RecycledProduct): bool {
        product.original_creator_type == b"recycler"
    }

    // ✅ Fonction pour transférer le produit recyclé (vente, distribution, etc.)
    public entry fun transfer_product(
        product: RecycledProduct,
        recipient: address,
        _ctx: &mut tx_context::TxContext,
    ) {
        iota::transfer::transfer(product, recipient);
    }
}