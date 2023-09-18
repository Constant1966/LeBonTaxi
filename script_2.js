
    // const listItems = document.querySelectorAll('.list-group-item');
    // const carouselItems = document.querySelectorAll('.carousel-item');

    // listItems.forEach((item, index) => {
    //     item.addEventListener('click', () => {
    //         // Supprime la classe "active" de tous les éléments du carrousel.
    //         carouselItems.forEach(carouselItem => {
    //             carouselItem.classList.remove('active');
    //         });

    //         // Ajoute la classe "active" à l'élément du carrousel correspondant.
    //         carouselItems[index].classList.add('active');
    //     });
    // });


    const listItems = document.querySelectorAll('.list-group-item');
    const carouselItems = document.querySelectorAll('.carousel-item');

    function updateActiveItem(index) {
        // Supprime la classe "active" de tous les éléments de la liste.
        listItems.forEach(item => {
            item.classList.remove('active');
        });

        // Ajoute la classe "active" à l'élément de liste correspondant.
        listItems[index].classList.add('active');
    }

    listItems.forEach((item, index) => {
        item.addEventListener('click', () => {
            // Supprime la classe "active" de tous les éléments du carrousel.
            carouselItems.forEach(carouselItem => {
                carouselItem.classList.remove('active');
            });

            // Ajoute la classe "active" à l'élément du carrousel correspondant.
            carouselItems[index].classList.add('active');

            // Met à jour l'élément actif de la liste.
            updateActiveItem(index);
        });
    });

    // Suivre le changement automatique du carrousel.
    const myCarousel = document.getElementById('myCarousel');
    myCarousel.addEventListener('slid.bs.carousel', event => {
        const activeIndex = event.to;
        // Met à jour l'élément actif de la liste lorsque le carrousel change automatiquement.
        updateActiveItem(activeIndex);
    });
